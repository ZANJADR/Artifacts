CLASS zcl_bpem_master_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    TYPES ty_entity TYPE zi_ce_bpem_inst_contract_data.
    TYPES tt_entity TYPE STANDARD TABLE OF ty_entity WITH DEFAULT KEY.

    METHODS get_contract_data
      IMPORTING io_request TYPE REF TO if_rap_query_request
      EXPORTING et_data    TYPE tt_entity
      RAISING   cx_rap_query_prov_not_impl
                cx_rap_query_provider.

    METHODS determine_supply_scenario
      CHANGING ct_data TYPE tt_entity.
ENDCLASS.


CLASS zcl_bpem_master_data IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA lt_data TYPE tt_entity.

    TRY.
        get_contract_data(
          EXPORTING io_request = io_request
          IMPORTING et_data    = lt_data ).

        " Supply scenario logic (FM call)
        determine_supply_scenario( CHANGING ct_data = lt_data ).

        IF io_request->is_total_numb_of_rec_requested( ).
          io_response->set_total_number_of_records( lines( lt_data ) ).
        ENDIF.

        IF io_request->is_data_requested( ).
          " Paging is applied in get_contract_data; just return the result
          io_response->set_data( lt_data ).
        ENDIF.

      CATCH cx_rap_query_prov_not_impl cx_rap_query_provider INTO DATA(lx_rap).
        RAISE EXCEPTION lx_rap.
      CATCH cx_root INTO DATA(lx_root).
        RAISE EXCEPTION TYPE cx_rap_query_provider
          EXPORTING previous = lx_root.
    ENDTRY.
  ENDMETHOD.


  METHOD get_contract_data.
    DATA lt_sort TYPE STANDARD TABLE OF string WITH DEFAULT KEY.

    " ---- Filter ----
    DATA(lv_where) = `1 = 1`.
    TRY.
        DATA(lv_filter) = io_request->get_filter( )->get_as_sql_string( ).
        IF lv_filter IS NOT INITIAL.
          lv_where = lv_filter.
        ENDIF.
      CATCH cx_rap_query_filter_no_range.
        " no filter supplied -> read all
    ENDTRY.

    " ---- Sorting ----
    DATA(lt_sort_elem) = io_request->get_sort_elements( ).
    LOOP AT lt_sort_elem INTO DATA(ls_sort).
      APPEND |{ ls_sort-element_name }{ COND #( WHEN ls_sort-descending = abap_true THEN ` DESCENDING` ELSE ` ASCENDING` ) }|
        TO lt_sort.
    ENDLOOP.
    IF lt_sort IS INITIAL.
      APPEND `UtilitiesContract` TO lt_sort.
    ENDIF.
    DATA(lv_order_by) = concat_lines_of( table = lt_sort sep = `, ` ).

    " ---- Paging ----
    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_offset) = lo_paging->get_offset( ).
    DATA(lv_page)   = lo_paging->get_page_size( ).
    DATA(lv_up_to)  = COND i( WHEN lv_page = if_rap_query_paging=>page_size_unlimited THEN 0 ELSE lv_page ).

    " ---- Read from CDS data model ----
    SELECT *
      FROM zi_bpem_inst_contract_data
      WHERE (lv_where)
      ORDER BY (lv_order_by)
      INTO CORRESPONDING FIELDS OF TABLE @et_data
      UP TO @lv_up_to ROWS
      OFFSET @lv_offset.
  ENDMETHOD.


  METHOD determine_supply_scenario.
    TYPES: BEGIN OF ty_inst_ui,
             anlage TYPE euiinstln-anlage,
             int_ui TYPE euiinstln-int_ui,
           END OF ty_inst_ui,
           BEGIN OF ty_ever,
             vertrag TYPE ever-vertrag,
             auszdat TYPE ever-auszdat,
           END OF ty_ever.

    DATA: lt_inst_ui  TYPE SORTED TABLE OF ty_inst_ui WITH NON-UNIQUE KEY anlage,
          lt_ever     TYPE SORTED TABLE OF ty_ever    WITH UNIQUE KEY vertrag,
          lv_keydate  TYPE sy-datum,
          ls_scenario TYPE eideswtscenario,    " check type of Y_SCENARIO in SE37
          lv_scentxt  TYPE eideswtscenariotxt. " check type of Y_SCENARIOTXT in SE37

    IF ct_data IS INITIAL.
      RETURN.
    ENDIF.

    " ---- Read EUIINSTLN once for ALL installations ----
    DATA(lt_anlage) = VALUE string_table( ).
    SELECT DISTINCT utilitiesinstallation
      FROM @ct_data AS data
      WHERE utilitiesinstallation IS NOT INITIAL
      INTO TABLE @DATA(lt_installations).

    IF lt_installations IS NOT INITIAL.
      SELECT anlage, int_ui
        FROM euiinstln
        FOR ALL ENTRIES IN @lt_installations
        WHERE anlage = @lt_installations-utilitiesinstallation
        INTO CORRESPONDING FIELDS OF TABLE @lt_inst_ui.
    ENDIF.

    " ---- Read EVER once for ALL contracts (key date = EVER-AUSZDAT) ----
    SELECT DISTINCT utilitiescontract
      FROM @ct_data AS data
      WHERE utilitiescontract IS NOT INITIAL
      INTO TABLE @DATA(lt_contracts).

    IF lt_contracts IS NOT INITIAL.
      SELECT vertrag, auszdat
        FROM ever
        FOR ALL ENTRIES IN @lt_contracts
        WHERE vertrag = @lt_contracts-utilitiescontract
        INTO CORRESPONDING FIELDS OF TABLE @lt_ever.
    ENDIF.

    " ---- Call FM per row using buffered data ----
    LOOP AT ct_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      CLEAR: lv_keydate, ls_scenario, lv_scentxt.

      READ TABLE lt_inst_ui INTO DATA(ls_inst_ui)
           WITH KEY anlage = <ls_data>-utilitiesinstallation.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      READ TABLE lt_ever INTO DATA(ls_ever)
           WITH KEY vertrag = <ls_data>-utilitiescontract.
      IF sy-subrc = 0 AND ls_ever-auszdat IS NOT INITIAL.
        lv_keydate = ls_ever-auszdat.
      ELSE.
        lv_keydate = '99991231'.
      ENDIF.

      CALL FUNCTION 'ISU_O_SCENARIO_AT_POD_GET'
        EXPORTING
          x_int_ui      = ls_inst_ui-int_ui
          x_keydate     = lv_keydate
        IMPORTING
          y_scenario    = ls_scenario
          y_scenariotxt = lv_scentxt
        EXCEPTIONS
          OTHERS        = 1.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      <ls_data>-supplyscenario            = ls_scenario-scenario.
      <ls_data>-supplyscenariodescription = lv_scentxt.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
