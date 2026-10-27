# Artifacts

## BPEM contract data

The interface view keeps real data, while the contract projection adds the
virtual supply-scenario fields. The history projection redirects its contract
association to that projection. Other exposed views remain unchanged.

```text
ZI_bpem_inst_contract_data (interface, + ServiceProviderType)
   -> ZC_bpem_inst_contract_data (projection, + virtual SupplyScenario/Description)
ZI_bpem_installation_hist_data (interface, unchanged)
   -> ZC_bpem_installation_hist_data (projection, redirects _UtilitiesContract to the ZC contract view)
```

Activation order: wrapper view -> interface view -> class -> ZC contract
projection -> ZC history projection -> service definition. Republish the
service binding after activation.

### SAP-system verification items

- Verify the `IF_SADL_EXIT_CALC_ELEMENT_READ` signatures and the exact
  `ISU_O_SCENARIO_AT_POD_GET` parameter names and types, including
  `Y_SCENARIO-SCE` and `Y_SCENARIOTXT`, in SE37.
- Verify whether a read-only `as projection on` a plain view entity without a
  RAP BO activates in the target release. If not, use a regular
  `define view entity ... as select from ZI_bpem_inst_contract_data`
  consumption view with the same virtual-element annotations.
- Confirm that `EVER-AUSZDAT` equals the exposed `UtilitiesMoveOutDate` and
  that `99991231` is the appropriate default for open contracts.
- Virtual elements cannot be used in `$filter` or `$orderby`.
- Confirm that the FM is safe in an OData read context (no `COMMIT WORK` or
  problematic global state) and whether it applies authority checks.
- Other exposed views are unchanged; only the contract and installation-history
  views receive a projection layer.