@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'BPEM Service Provider Type'
define view entity ZI_bpem_servprov_type
  as select from eservprov
{
  key serviceid as UtilitiesServiceProvider,
      zzsp_typ  as ServiceProviderType
}
