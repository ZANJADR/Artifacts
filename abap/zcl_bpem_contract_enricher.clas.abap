CLASS zcl_bpem_contract_enricher DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES tt_contracts TYPE STANDARD TABLE OF zi_bpem_inst_contract_data
      WITH EMPTY KEY.

    TYPES BEGIN OF ty_enriched.
    INCLUDE TYPE zi_bpem_inst_contract_data.
    TYPES:
      SupplyScenario            TYPE string,
      SupplyScenarioDescription TYPE string,
      ScenarioResolutionStatus  TYPE c LENGTH 1,
      END OF ty_enriched.

    TYPES tt_enriched TYPE STANDARD TABLE OF ty_enriched WITH EMPTY KEY.

    METHODS constructor
      IMPORTING io_resolver TYPE REF TO zif_bpem_scenario_resolver.

    METHODS enrich
      IMPORTING
        it_contracts TYPE tt_contracts
        iv_key_date  TYPE d
        iv_language  TYPE sylangu DEFAULT sy-langu
      RETURNING
        VALUE(rt_contracts) TYPE tt_enriched.

  PRIVATE SECTION.
    DATA mo_resolver TYPE REF TO zif_bpem_scenario_resolver.
ENDCLASS.

CLASS zcl_bpem_contract_enricher IMPLEMENTATION.
  METHOD constructor.
    mo_resolver = io_resolver.
  ENDMETHOD.

  METHOD enrich.
    TYPES:
      BEGIN OF ty_cache,
        installation TYPE zi_bpem_inst_contract_data-UtilitiesInstallation,
        result       TYPE zif_bpem_scenario_resolver=>ty_result,
      END OF ty_cache.
    DATA lt_cache TYPE HASHED TABLE OF ty_cache
      WITH UNIQUE KEY installation.
    DATA ls_result TYPE zif_bpem_scenario_resolver=>ty_result.

    LOOP AT it_contracts INTO DATA(ls_contract).
      CLEAR ls_result.
      READ TABLE lt_cache
        WITH TABLE KEY installation = ls_contract-UtilitiesInstallation
        INTO DATA(ls_cached).
      IF sy-subrc = 0.
        ls_result = ls_cached-result.
      ELSE.
        ls_result-status = zif_bpem_scenario_resolver=>missing.
        IF iv_key_date IS INITIAL OR iv_language IS INITIAL
          OR mo_resolver IS NOT BOUND.
          ls_result-status = zif_bpem_scenario_resolver=>failed.
        ELSEIF ls_contract-UtilitiesInstallation IS NOT INITIAL.
          TRY.
              ls_result = mo_resolver->resolve(
                iv_installation = ls_contract-UtilitiesInstallation
                iv_key_date     = iv_key_date
                iv_language     = iv_language ).
            CATCH cx_static_check.
              CLEAR ls_result.
              ls_result-status = zif_bpem_scenario_resolver=>failed.
          ENDTRY.
        ENDIF.

        CASE ls_result-status.
          WHEN zif_bpem_scenario_resolver=>found.
            IF ls_result-SupplyScenario IS INITIAL.
              ls_result-status = zif_bpem_scenario_resolver=>failed.
            ENDIF.
          WHEN zif_bpem_scenario_resolver=>missing
            OR zif_bpem_scenario_resolver=>ambiguous
            OR zif_bpem_scenario_resolver=>failed.
          WHEN OTHERS.
            ls_result-status = zif_bpem_scenario_resolver=>failed.
        ENDCASE.
        IF ls_result-status <> zif_bpem_scenario_resolver=>found.
          CLEAR: ls_result-SupplyScenario,
                 ls_result-SupplyScenarioDescription.
        ENDIF.
        INSERT VALUE #(
          installation = ls_contract-UtilitiesInstallation
          result       = ls_result ) INTO TABLE lt_cache.
      ENDIF.

      DATA(ls_enriched) = CORRESPONDING ty_enriched( ls_contract ).
      ls_enriched-ServiceProvider = ls_contract-UtilitiesServiceProvider.
      ls_enriched-SupplyScenario = ls_result-SupplyScenario.
      ls_enriched-SupplyScenarioDescription =
        ls_result-SupplyScenarioDescription.
      ls_enriched-ScenarioResolutionStatus = ls_result-status.
      APPEND ls_enriched TO rt_contracts.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
