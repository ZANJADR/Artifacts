Subroutine price_upld_email: Subroutine responsible for generating and sending price upload emails. Similar to price_calculation_email, it fetches data from database tables like (ZUB_MIDAS_ERROR, ZUB_MIDAS_CALC, and ZUB_MIDAS_STATS), formats content, and handles attachments. 

When error_type “PRICE_UPLD” (calling from program ZUB_E_MIDAS_PRICE_UPLOAD), follow the logic below. 

Fetch all records from table ZUB_MIDAS_ERROR based on log date, PROCESS NAME = PRICE_UPLD with STATUS= OPEN 

Validating Rate Type ‘RTP’, ‘CPP’ and ‘TOU’ 

Get all the RIN’s for Unsuccess and create a .csv file. 

Select Email content from transaction S010 for email body. Text name= ZRTP_ PRICE_UPLD 

Subject and Distribution List are fetched from table ZDBDV_HCODE_DTL with Val Id =2806 Email notification. 

Start of MIDAS 2.0 Version 0.4 

Error Type = PRICE_UPLD  

Updated the existing query for data fetch from ZUB_MIDAS_STATS Table. Commented where condition for upload_midas And added condition to fetch data based on pt_job_id[]-job_id passed in input from calling program. 

Email Body: The RTP/CPP/TOU run cycle has been completed for the “MIDAS PRICE_UPLD Process" at yyyy.mm.dd hh:mm (2024.02.05 13:12). 

Subject: CPP/RTP/TOU- “MIDAS Price Upload Process” at yyyy.mm.dd hh:mm 

 

Email Body: Update Standard Texts in T-Code SO10 - ZRTP_UPLD / ZCPP_UPLD / ZTOU_UPLD as below: 

 

The CPP/RTP/TOU run cycle has been completed for the "MIDAS PRICE_UPLD Request Process with Job ID" at yyyy/mm/dd hh:mm.  
Unsuccess = 5 .  
Success = 0 .  
Exclude = 0 .  

Subject: Update config in ZDBUB_HCODE_DTL with ID_NUM = 2806 as below a  

ID_NUM 

KEY_NAME 

VAL_LOW (Updated) 

2806 

ZCPP_UPLD 

MIDAS CPP Price Upload Request Job ID at 

2806 

ZRTP_UPLD 

MIDAS RTP Price Upload Request Job ID at 

2806 

ZTOU_UPLD 

MIDAS TOU Price Upload Request Job ID at 

 

Sample Subject: MIDAS CPP/RTP/TOU Price Upload Request Job ID at yyyy.mm.dd hh:mm   

 

Error Type = PRICE_UPLD_02  

Add logic to fetch data from database tables like (ZUB_MIDAS_ERROR, and ZUB_MIDAS_STATS), formats content, and handles attachments. 

Create CDS Views - ZVUB_CDS_MIDAS_ERROR, ZVUB_CDS_MIDAS_RATEINFO, ZVUB_CDS_MIDAS_STATS to fetch data from tables zub_midas_error, zub_midas_rinfo, zub_midas_stats respectively. 

When error_type “PRICE_UPLD_02” (calling from RAP application job Class - ZCL_UB_MIDAS_JOBID_PROCESS), follow the logic below. 

Fetch all records from CDS View zvub_cds_midas_error inner join zvub_cds_midas_rateinfo based on pt_job_id-rin, log date, ratetype, PROCESS NAME = JOB_UPLD, error_type = PRICE_UPLD_02 with STATUS= OPEN 

Validating Rate Type ‘RTP’, ‘CPP’ and ‘TOU’ 

Get all the RIN’s for Unsuccess and create a .csv file. 

Fetch success data from table ZUB_MIDAS_STATS ( CDS view zvub_cds_midastats) ) based on pt_job_id-rin, upload_midas <> ‘00000000’, job_id  = pt_job_id-job_id. 

Select Email content from transaction S010 for email body. Text name= ZCPP_UPLD_02 / ZRTP_UPLD_02 / ZTOU_UPLD_02 

Subject and Distribution List are fetched from table ZDBDV_HCODE_DTL with Val Id =2806 and key = ‘EMAIL_UPLD_TO’ & ‘EMAIL_UPLD_CC’ Email notification. 

Email Body: Create new Standard Texts - ZRTP_UPLD_02 / ZCPP_UPLD_02 / ZTOU_UPLD_02 as below: 

 

MIDAS 2.0 PRICE_UPLD for TOU/RTP/CPP run cycle has been completed at yyyy.mm.dd hh:mm 
Unsuccess = 0.  
Success = 1.  

Subject: Create config in ZDBUB_HCODE_DTL with ID_NUM = 2806 as below: 

ID_NUM 

KEY_NAME 

VAL_LOW (Updated) 

2806 

ZPRC_UPLD_02 

MIDAS 2.0 &1 Price Upload Completed at 

 

Replace &1 with rate type (RTP/CPP/TOU). 

Sample Subject:  MIDAS 2.0 TOU/RTP/CPP Price Upload Completed at yyyy.mm.dd hh:mm 

.CSV attachment will be sent in email with unsuccess RIN data. 

                             End of MIDAS 2.0 Version 0.4 
