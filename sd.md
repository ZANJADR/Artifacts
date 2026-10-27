@EndUserText.label: 'Srv Def for BPEM Master Data'
define service ZSR_BPEM_master_data {
  expose ZI_BPEM_MASTER_DATA            as BPEM_Master_Data;
  expose Zi_bpem_device_location_data   as BPEM_DeviceLoc;
  expose ZC_bpem_installation_hist_data as BPEM_Installation_Hist_Data;
  expose zi_zdbdd_volt_level            as BPEM_Volt_Level;
  expose ZC_bpem_inst_contract_data     as BPEM_Inst_Contract_Data;
  expose zi_bpem_contract_ac_data       as BPEM_Contract_AC_Data;
  expose zi_bpem_contract_business_lock as BPEM_Contract_Business_Lock;
}
