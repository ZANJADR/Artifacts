@EndUserText.label: 'BPEM Installation Contract Data - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_bpem_inst_contract_data
  as projection on ZI_bpem_inst_contract_data
{
  key UtilitiesContract,
      UtilitiesAccountDetnCode,
      UtilitiesAccountDetnCodeName,
      UtilsBillgBlockReason,
      UtilsBillgBlockReasonName,
      UtilitiesInstallation,
      UtilitiesServiceProvider,
      ServiceProviderType,
      ContractAccount,
      UtilitiesMoveInDate,
      UtilitiesMoveOutDate,
      ContPaymentPlanType,
      ContStartingMonthofPaymentPlan,
      IsOnJointInvoicing,
      UtilsContractCreationDate,
      UtilsContractCreatedByUser,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_BPEM_SUPPLY_SCENARIO'
      virtual SupplyScenario            : abap.char(10),
      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_BPEM_SUPPLY_SCENARIO'
      virtual SupplyScenarioDescription : abap.char(60),

      _ContractAccountPartner,
      _JointInvoiceStatus,
      _ServProvType
}
