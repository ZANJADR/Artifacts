/***********************************************************************
* CDS View Name : ZI_bpem_inst_contract_data
* Description   : BPEM Installation Contracat Data
*----------------------------------------------------------------------
* Change History
*----------------------------------------------------------------------
* Date       | Developer        | Change Request | Description
*----------------------------------------------------------------------
* 10/16/2026 | PARASAR          |                | Using 'ContractAccount'
* to CDS View 'ZI_BPEM_CA_JOINT_INV_STATUS' to find the Joint vs Single              
* 10/27/2026 |                  |                | Added ServiceProviderType via ZI_bpem_servprov_type
***********************************************************************/
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BPEM Installation Contracat Data'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_bpem_inst_contract_data
  as select from I_UtilitiesContract as _UtilitiesContract
  association [0..*] to zi_bpem_contract_ac_data    as _ContractAccountPartner on  $projection.ContractAccount = _ContractAccountPartner.ContractAccount
  association [0..1] to I_UtilsAccountDetnCodeText  as _ActDetCdText           on  $projection.UtilitiesAccountDetnCode = _ActDetCdText.UtilitiesAccountDetnCode
                                                                               and _ActDetCdText.Language               = $session.system_language
                                                                               and _ActDetCdText.Division               = _UtilitiesContract.UtilitiesDivision
  association [0..1] to I_UtilsBillgBlockReasonT    as _BillgBlockReasonT      on  $projection.UtilsBillgBlockReason = _BillgBlockReasonT.UtilsBillgBlockReason
                                                                               and _BillgBlockReasonT.Language       = $session.system_language
// Begin of change PARASAR-AI_BPEM Project                                                                               
  //  association [0..1] to ZI_BPEM_CA_JOINT_INV_STATUS as _JointInvoiceStatus     on  $projection.UtilitiesContract = _JointInvoiceStatus.UtilitiesContract
  association [0..1] to ZI_BPEM_CA_JOINT_INV_STATUS as _JointInvoiceStatus     on  $projection.ContractAccount = _JointInvoiceStatus.ContractAccount
// End of change PARASAR-AI_BPEM Project
  association [0..1] to ZI_bpem_servprov_type as _ServProvType
    on $projection.UtilitiesServiceProvider = _ServProvType.UtilitiesServiceProvider
{
  key UtilitiesContract,
      UtilitiesAccountDetnCode,
      _ActDetCdText.UtilitiesAccountDetnCodeName        as UtilitiesAccountDetnCodeName,
      UtilsBillgBlockReason,
      _BillgBlockReasonT.UtilsBillgBlockReasonName      as UtilsBillgBlockReasonName,
      UtilitiesInstallation,
      UtilitiesServiceProvider,
      _ServProvType.ServiceProviderType                 as ServiceProviderType,
      ContractAccount,
      cast( UtilitiesMoveInDate as abap.char(10))       as UtilitiesMoveInDate,
      cast( UtilitiesMoveOutDate as abap.char(10))      as UtilitiesMoveOutDate,
      ContPaymentPlanType,
      ContStartingMonthofPaymentPlan,
      _JointInvoiceStatus.IsOnJointInvoicing            as IsOnJointInvoicing,
      cast( UtilsContractCreationDate as abap.char(10)) as UtilsContractCreationDate,
      UtilsContractCreatedByUser,
      _ContractAccountPartner,
      _JointInvoiceStatus,
      _ServProvType
}
where
  UtilitiesInstallation is not null
