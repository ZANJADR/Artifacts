@EndUserText.label: 'BPEM Installation History Data - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define view entity ZC_bpem_installation_hist_data
  as projection on ZI_bpem_installation_hist_data
{
  key UtilitiesInstallation,
  key UtilsInstHistValidityEndDate,
      UtilsInstHistValidityStartDate,
      UtilitiesRateCategory,
      UtilitiesRateCategoryName,
      UtilitiesBillingClass,
      UtilitiesBillingClassName,
      MeterReadingUnit,
      PrimaryUtilitiesInstallation,
      UtilsInstallationGroupRole,
      UtilsInstallationGroupRoleName,
      UtilsInstallationGroupType,
      UtilsInstallationGroupTypeName,
      _UtilitiesContract : redirected to ZC_bpem_inst_contract_data
}
