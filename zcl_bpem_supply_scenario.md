CLASS zcl_bpem_supply_scenario DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_row,
        utilitiesinstallation     TYPE c LENGTH 10,
        utilitiesmoveoutdate      TYPE c LENGTH 10,
        supplyscenario            TYPE c LENGTH 10,
        supplyscenariodescription TYPE c LENGTH 60,
      END OF ty_row,
      tt_row TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY,

      BEGIN OF ty_ui,
        anlage TYPE euiinstln-anlage,
        int_ui TYPE euiinstln-int_ui,
      END OF ty_ui,
      tt_ui TYPE SORTED TABLE OF ty_ui WITH UNIQUE KEY anlage,

      BEGIN OF ty_cache,
        int_ui   TYPE euiinstln-int_ui,
        keydate  TYPE d,
        scenario TYPE c LENGTH 10,
        text     TYPE c LENGTH 60,
      END OF ty_cache,
      tt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY int_ui keydate.

    CLASS-METHODS to_keydate
      IMPORTING iv_char        TYPE clike
      RETURNING VALUE(rv_date) TYPE d.
ENDCLASS.


CLASS zcl_bpem_supply_scenario IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    et_requested_orig_elements = VALUE #(
      ( `UTILITIESINSTALLATION` )
      ( `UTILITIESMOVEOUTDATE` ) ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.

    DATA lt_rows  TYPE tt_row.
    DATA lt_inst  TYPE STANDARD TABLE OF ty_ui WITH DEFAULT KEY.
    DATA lt_ui    TYPE tt_ui.
    DATA lt_cache TYPE tt_cache.

    IF NOT ( line_exists( it_requested_calc_elements[ table_line = `SUPPLYSCENARIO` ] )
          OR line_exists( it_requested_calc_elements[ table_line = `SUPPLYSCENARIODESCRIPTION` ] ) ).
      RETURN.
    ENDIF.

    lt_rows = CORRESPONDING #( it_original_data ).
    IF lt_rows IS INITIAL.
      RETURN.
    ENDIF.

    " 1. One bulk read: installation -> internal POD key
    lt_inst = VALUE #( FOR r IN lt_rows
                       ( anlage = r-utilitiesinstallation ) ).
    SORT lt_inst BY anlage.
    DELETE ADJACENT DUPLICATES FROM lt_inst COMPARING anlage.

    IF lt_inst IS NOT INITIAL.
      SELECT anlage, int_ui
        FROM euiinstln
        FOR ALL ENTRIES IN @lt_inst
        WHERE anlage = @lt_inst-anlage
        INTO CORRESPONDING FIELDS OF TABLE @lt_ui.
    ENDIF.

    " 2. One FM call per distinct (INT_UI, key date)
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<row>).

      CLEAR: <row>-supplyscenario, <row>-supplyscenariodescription.

      READ TABLE lt_ui ASSIGNING FIELD-SYMBOL(<ui>)
           WITH KEY anlage = <row>-utilitiesinstallation.
      IF sy-subrc <> 0 OR <ui>-int_ui IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_keydate) = to_keydate( <row>-utilitiesmoveoutdate ).

      READ TABLE lt_cache ASSIGNING FIELD-SYMBOL(<cache>)
           WITH TABLE KEY int_ui = <ui>-int_ui keydate = lv_keydate.

      IF sy-subrc <> 0.
        DATA(ls_new) = VALUE ty_cache( int_ui  = <ui>-int_ui
                                       keydate = lv_keydate ).

        CALL FUNCTION 'ISU_O_SCENARIO_AT_POD_GET'
          EXPORTING
            x_int_ui      = <ui>-int_ui
            x_keydate     = lv_keydate
          IMPORTING
            y_scenario    = DATA(ls_scenario)
            y_scenariotxt = DATA(lv_text)
          EXCEPTIONS
            OTHERS        = 1.

        IF sy-subrc = 0.
          ls_new-scenario = ls_scenario-sce.
          ls_new-text     = lv_text.
        ENDIF.

        INSERT ls_new INTO TABLE lt_cache ASSIGNING <cache>.
      ENDIF.

      <row>-supplyscenario            = <cache>-scenario.
      <row>-supplyscenariodescription = <cache>-text.
    ENDLOOP.

    " 3. Return values; row order unchanged
    ct_calculated_data = CORRESPONDING #( lt_rows ).

  ENDMETHOD.


  METHOD to_keydate.
    DATA(lv_in) = condense( CONV string( iv_char ) ).
    " Accepts YYYYMMDD and YYYY-MM-DD
    DATA(lv_digits) = replace( val = lv_in sub = `-` with = `` occ = 0 ).

    IF lv_digits IS INITIAL OR lv_digits = `00000000` OR strlen( lv_digits ) < 8.
      rv_date = '99991231'.
      RETURN.
    ENDIF.

    rv_date = lv_digits(8).
  ENDMETHOD.

ENDCLASS.
