INTERFACE zif_bpem_scenario_resolver PUBLIC.
  CONSTANTS:
    found     TYPE c LENGTH 1 VALUE 'F',
    missing   TYPE c LENGTH 1 VALUE 'N',
    ambiguous TYPE c LENGTH 1 VALUE 'A',
    failed    TYPE c LENGTH 1 VALUE 'E'.

  TYPES:
    BEGIN OF ty_result,
      SupplyScenario            TYPE string,
      SupplyScenarioDescription TYPE string,
      status                    TYPE c LENGTH 1,
    END OF ty_result.

  " Site-specific implementation must use ISU_O_SCENARIO_AT_POD_GET.
  METHODS resolve
    IMPORTING
      iv_installation TYPE zi_bpem_inst_contract_data-UtilitiesInstallation
      iv_key_date     TYPE d
      iv_language     TYPE sylangu
    RETURNING
      VALUE(rs_result) TYPE ty_result
    RAISING
      cx_static_check.
ENDINTERFACE.
