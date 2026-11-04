*----------------------------------------------------------------------*
***INCLUDE LZUB_MIDAS_MAILF01.
*----------------------------------------------------------------------*
**********************************************************************
* A D M I N I S T R A T I O N                                        *
**********************************************************************
* Program ID : LZUB_MIDAS_MAILF01                                    *
* Program Title : subroutin of MIDAS Email Trigger Notification      *
* Created by : AHMEDZ                                                *
* Created on : 26/02/2024                                            *
* Description : Include to implement the subroutines of MIDAS Email  *
* Transport Request : D03K936565                                     *
* Object ID : 2806                                                   *
**********************************************************************
* C H A N G E  H I S T O R Y                                         *
**********************************************************************
* MOD No|Changed on  |Changed by       |Change No   | Request no     *
*-------|------------|-----------------|------------|--------------- *
* 001   | 05/10/2024 | LAUW            |MIDAS R2    | D03K936565     *
*-------|------------|-----------------|------------|--------------- *
* 002   | 05/29/2024 | LIUM1           |MIDAS CR-013| D03K936565     *
* ------|------------|-----------------|------------|--------------- *
* 003   | 06/21/2024 | LIUM1           |Email ID Chg| S03K912541     *
*_------|------------|-----------------|------------|--------------- *
* 004   | 07/22/2024 | LIUM1           |MIDAS CR-017| S03K912724     *
*_------|------------|-----------------|------------|--------------- *
* 005   | 10/22/2024 | LIUM1           |MIDAS CR-018| S03K912724     *
*_------|------------|-----------------|------------|--------------- *
FORM price_upld_email TABLES pt_rin STRUCTURE isu_ranges
                       USING lv_process_name TYPE char04
                             lv_text TYPE char20
*                             lv_status TYPE abap_bool
*                             lv_recipient TYPE ad_smtpadr   "Mod-003--
*                             lv_date TYPE datum             "DEL-001--
                             ps_start TYPE isu_datetime      "INS-001++
                             ps_end   TYPE isu_datetime      "INS-001++
                        CHANGING cv_subject TYPE char50
                                 lv_status TYPE abap_bool.   "INS-001++

  DATA : lv_exclude TYPE string,
*         lr_date    TYPE RANGE OF datum,      "DEL-001--
         lr_rin     TYPE RANGE OF zde_rin
         .

* Begin of Mod-003++
  gv_recipient_to = 'EMAIL_UPLD_TO'.
  gv_recipient_cc = 'EMAIL_UPLD_CC'.
* End of Mod-003++

  IF pt_rin[] IS NOT INITIAL.
    lr_rin = VALUE #( FOR ls_rin IN pt_rin ( sign = 'I' option = 'EQ' low = ls_rin-low ) ).
  ENDIF.
*----> DEL-001--
*  IF lv_date IS NOT INITIAL.
*    lr_date = VALUE #( ( sign = 'I' option = 'EQ' low = lv_date ) ).
*  ENDIF.
*<---- DEL-001--

  "Fetching list of rate types and subject
  SELECT key_name, val_low
    FROM zdbdv_hcode_dtl
    INTO TABLE @DATA(li_hcode)
    WHERE id_type = @gc_idtype
    AND   id_num = @gc_idnum.
  IF sy-subrc EQ 0.
    READ TABLE li_hcode ASSIGNING FIELD-SYMBOL(<lfs_subject>)
                        WITH KEY key_name = cv_subject.
    cv_subject = <lfs_subject>-val_low.
  ENDIF.

  CASE lv_process_name.
    WHEN gc_rtp.
      gr_ratetype = VALUE #( FOR lw_hcode IN li_hcode WHERE ( key_name = gc_rate_rtp )
                                          ( sign = 'I'
                                            option = 'EQ'
                                            low = lw_hcode-val_low ) ).
    WHEN gc_cpp.
      gr_ratetype = VALUE #( FOR lw_hcode IN li_hcode WHERE ( key_name = gc_rate_cpp )
                                         ( sign = 'I'
                                           option = 'EQ'
                                           low = lw_hcode-val_low ) ).
    WHEN gc_tou.
      gr_ratetype = VALUE #( FOR lw_hcode IN li_hcode WHERE ( key_name = gc_rate_tou )
                                         ( sign = 'I'
                                           option = 'EQ'
                                           low = lw_hcode-val_low ) ).
  ENDCASE.

  SELECT DISTINCT process_name, b~rin, error_type, log_date, error_desc,
   error_desc1, error_code, error_message, status, aedat
    FROM zub_midas_error AS a
    INNER JOIN zub_midas_rinfo AS b ON a~rin EQ b~rin
    INTO TABLE @DATA(li_upld_error)
     WHERE b~rin      IN @lr_rin
*      AND log_date    IN @lr_date                                "DEL-001--
      AND log_date    BETWEEN @ps_start-date AND @ps_end-date     "INS-001--
      AND status       = @gc_open
      AND error_type   = @gc_price_upld
      AND process_name = @gc_price
      AND ratetype    IN @gr_ratetype.
  IF sy-subrc NE 0.
    "Check if there's any system error
    SELECT process_name, rin, error_type, log_date, error_desc,
           error_desc1, error_code, error_message, status, aedat
      FROM zub_midas_error
      INTO TABLE @li_upld_error
      WHERE rin        EQ @space   "Blank RIN = system issue
*      AND log_date    IN @lr_date                                "DEL-001--
      AND log_date     BETWEEN @ps_start-date AND @ps_end-date     "INS-001--
      AND status       EQ @gc_open
      AND error_type   EQ @gc_price_upld
      AND process_name EQ @gc_price.
  ENDIF.

  " Check and count entries in li_upld_error
  gv_fail_count = COND #( WHEN sy-subrc = 0 THEN lines( li_upld_error ) ELSE 0 ).

  SELECT DISTINCT rin FROM zub_midas_stats
  INTO TABLE @DATA(li_zub_upd_succ)
  WHERE rin         IN @lr_rin
*    AND upload_midas = @sy-datum                                 "DEL-001--
    AND upload_midas BETWEEN @ps_start-date AND @ps_end-date     "INS-001--
    AND rate_type   IN @gr_ratetype.

  " Check and count entries in li_zub_upd_succ
  gv_success_count = COND #( WHEN sy-subrc = 0 THEN lines( li_zub_upd_succ ) ELSE 0 ).

  "Fetching Excluded data from table.
  SELECT * FROM zub_midas_excld INTO TABLE @DATA(li_excld)
    WHERE rin   IN @lr_rin
      AND status = @gc_open
      AND ratetype IN @gr_ratetype.

  " Check and count entries in li_excld
  lv_exclude = COND #( WHEN sy-subrc = 0 THEN lines( li_excld ) ELSE 0 ).

  PERFORM call_read_text USING lv_text CHANGING gtt_lines.

  WRITE sy-datum TO gv_date DD/MM/YYYY.
  DATA(lv_time) = |{ sy-uzeit TIME = ENVIRONMENT }|.

  TRY. "Creating body for email from SO10 Text.
      CLEAR gtt_text.
      LOOP AT gtt_lines INTO DATA(lw_lines).
        lo_send_request = cl_bcs=>create_persistent( ).
        REPLACE ALL OCCURRENCES OF '@date@' IN lw_lines WITH gv_date.
        REPLACE ALL OCCURRENCES OF '@time@' IN lw_lines WITH lv_time.
        REPLACE ALL OCCURRENCES OF '@unsuccess@' IN lw_lines WITH gv_fail_count.
        REPLACE ALL OCCURRENCES OF '@success@' IN lw_lines WITH gv_success_count.
        REPLACE ALL OCCURRENCES OF '@exclude@' IN lw_lines WITH lv_exclude.
        gw_text-line = lw_lines.
        APPEND gw_text TO gtt_text.
        CLEAR gw_text.
      ENDLOOP.
*      IF sy-sysid NE 'P03'.
      IF gv_prod EQ abap_false.
        gw_text-line = '<BR></BR>'.
        APPEND gw_text TO gtt_text.
        gw_text-line = | Email sent from { sy-sysid }. |.
        APPEND gw_text TO gtt_text.
        CLEAR gw_text.
      ENDIF.
*END OF BODY

      TRY.
          lo_document = cl_document_bcs=>create_document(
          EXPORTING
          i_type = 'HTM'
          i_text = gtt_text
          i_subject = |{ cv_subject } { gv_date } { lv_time+0(5) }| ).
        CATCH cx_document_bcs INTO go_excep_handler. " BCS: Document Exceptions
          PERFORM exception_handling.
      ENDTRY.

      lo_send_request->set_document( lo_document ).
    CATCH cx_send_req_bcs INTO go_excep_handler.
      PERFORM exception_handling.
  ENDTRY.

*SET ATTACHMENT
  IF gv_fail_count GT 0.
    gv_attach = abap_true.
    CONCATENATE 'RIN'
                'RATE TYPE'
                'ERROR TYPE'
                'ERROR MESSAGE'
                'ERROR_DESC'
                'ERROR DESCRIPTION'
                'ERROR CODE'
                      INTO gv_string
                      SEPARATED BY cl_abap_char_utilities=>horizontal_tab.
    gv_data_string = gv_string.

    SORT li_upld_error BY process_name.

    LOOP AT li_upld_error INTO DATA(lw_upld_error).

      CONCATENATE lw_upld_error-rin
                  lw_upld_error-process_name
                  lw_upld_error-error_type
                  lw_upld_error-error_message
                  lw_upld_error-error_desc
                  lw_upld_error-error_desc1
                  lw_upld_error-error_code
                  INTO gv_string
                  SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

      CONCATENATE gv_data_string gv_string
             INTO gv_data_string
             SEPARATED BY cl_abap_char_utilities=>newline.
    ENDLOOP.
  ENDIF.

*SET ATTACHMENT FOR EXCLUDE.
  IF lv_exclude GT 0.
    gv_excld_attach = abap_true.

    "Creating Attachment Header
    CONCATENATE 'EXCLUDE_RIN'
                'EXCLUDE RATETYPE'
                'EXCLUDE STATUS'
                      INTO gv_string
                      SEPARATED BY cl_abap_char_utilities=>horizontal_tab.
    gv_excld_string = gv_string.

    "Creating Attachment Body
    LOOP AT li_excld INTO DATA(wa_excld).
      CONCATENATE wa_excld-rin
                  wa_excld-ratetype
                  wa_excld-status
                  INTO gv_string
                  SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

      CONCATENATE gv_excld_string gv_string
             INTO gv_excld_string
             SEPARATED BY cl_abap_char_utilities=>newline.
    ENDLOOP.
  ENDIF.

  PERFORM send_mail USING gv_data_string
*                          lv_recipient       "Mod-003--
                          gv_recipient_to     "Mod-003++
                          gv_excld_attach gv_excld_string gv_attach
*                          space  "Mod-002++ "Mod-003--
                          gv_recipient_cc     "Mod-003++
                    CHANGING lv_status.

  CLEAR: gv_recipient_to, gv_recipient_cc. "Mod-003++
ENDFORM.

FORM price_calculation_email  TABLES pt_rin STRUCTURE isu_ranges
                              USING lv_process_name TYPE char04
                                    lv_text TYPE char20
*                                    lv_status TYPE abap_bool
*                                    lv_recipient TYPE ad_smtpadr   "Mod-003--
*                                    lv_date TYPE datum             "DEL-001--
                                    ps_start TYPE isu_datetime      "INS-001++
                                    ps_end  TYPE isu_datetime
                              CHANGING cv_subject TYPE char50
                                       lv_status TYPE abap_bool.   "INS-001++

  DATA : lv_exclude TYPE string,
*         lr_date    TYPE RANGE OF datum,            "DEL-001--
         lr_rin     TYPE RANGE OF zde_rin
         .

* Begin of Mod-003++
  gv_recipient_to = 'EMAIL_CALC_TO'.
  gv_recipient_cc = 'EMAIL_CALC_CC'.
* End of Mod-003++

  IF pt_rin[] IS NOT INITIAL.
    lr_rin = VALUE #( FOR ls_rin IN pt_rin ( sign = 'I' option = 'EQ' low = ls_rin-low ) ).
  ENDIF.
*----> DEL-001--
*  IF lv_date IS NOT INITIAL.
*    lr_date = VALUE #( ( sign = 'I' option = 'EQ' low = lv_date ) ).
*  ENDIF.
*<---- DEL-001--

  "Fetching list of rate types and subject
  SELECT key_name, val_low
    FROM zdbdv_hcode_dtl
    INTO TABLE @DATA(li_hcode)
    WHERE id_type = @gc_idtype
    AND id_num = @gc_idnum.
  IF sy-subrc EQ 0.
    READ TABLE li_hcode ASSIGNING FIELD-SYMBOL(<lfs_subject>)
                        WITH KEY key_name = cv_subject.
    cv_subject = <lfs_subject>-val_low.
  ENDIF.

  CASE lv_process_name.
    WHEN gc_rtp.
      IF lr_rin[] IS NOT INITIAL.
        "Temperature with RIN
        APPEND VALUE #(  sign = 'I' option = 'EQ' low = space ) TO lr_rin.
      ENDIF.
      gr_ratetype = VALUE #( FOR lw_hcode IN li_hcode WHERE ( key_name = gc_rate_rtp )
                                          ( sign = 'I'
                                            option = 'EQ'
                                            low = lw_hcode-val_low ) ).

    WHEN gc_cpp.
      gr_ratetype = VALUE #( FOR lw_hcode IN li_hcode WHERE ( key_name = gc_rate_cpp )
                                         ( sign = 'I'
                                           option = 'EQ'
                                           low = lw_hcode-val_low ) ).

    WHEN gc_tou.
      gr_ratetype = VALUE #( FOR lw_hcode IN li_hcode WHERE ( key_name = gc_rate_tou )
                                         ( sign = 'I'
                                           option = 'EQ'
                                           low = lw_hcode-val_low ) ).

  ENDCASE.

  "Fetching Price Calculation Error based on Process Name.
  SELECT * FROM zub_midas_error
    INTO TABLE @DATA(li_price_calc)
    WHERE error_type = @gc_calc
*      AND log_date  IN @lr_date                                "DEL-001--
      AND log_date  BETWEEN @ps_start-date AND @ps_end-date     "INS-001--
      AND rin       IN @lr_rin
      AND status     = @gc_open
         AND process_name IN @gr_ratetype.

  " Check and count entries in li_price_calc
  gv_fail_count = COND #( WHEN sy-subrc = 0 THEN lines( li_price_calc ) ELSE 0 ).

  "Fetching Excluded data from table.
  SELECT * FROM zub_midas_excld INTO TABLE @DATA(li_excld)
    WHERE rin      IN @lr_rin
      AND status    = @gc_open
      AND ratetype IN @gr_ratetype.

  " Check and count entries in li_excld
  lv_exclude = COND #( WHEN sy-subrc = 0 THEN lines( li_excld ) ELSE 0 ).

*-----> MOD-001++
*  SELECT DISTINCT rin FROM zub_midas_stats
*  INTO TABLE @DATA(li_zub_upd_succ)
*   WHERE rin        IN @lr_rin
*      AND calc_midas = @sy-datum
*      AND rate_type IN @gr_ratetype.

  SELECT rin, calc_midas, calc_midas_time FROM zub_midas_stats
   WHERE rin        IN @lr_rin
     AND calc_midas BETWEEN @ps_start-date AND @ps_end-date
     AND rate_type IN @gr_ratetype
    INTO TABLE @DATA(li_zub_upd_succ).

  DELETE li_zub_upd_succ WHERE calc_midas = ps_start-date AND calc_midas_time LT ps_start-time.
  DELETE li_zub_upd_succ WHERE calc_midas = ps_end-date AND calc_midas_time GT ps_end-time.

  SORT li_zub_upd_succ BY rin.
  DELETE ADJACENT DUPLICATES FROM li_zub_upd_succ COMPARING rin.
*<----- MOD-001++

  " Check and count entries in li_zub_upd_succ
*  gv_success_count = COND #( WHEN sy-subrc = 0 THEN lines( li_zub_upd_succ ) ELSE 0 ).         "DEL-001--
  gv_success_count = lines( li_zub_upd_succ ).                                                  "INS-001++

  "Fetching text from SO10 for email body
  PERFORM call_read_text USING lv_text CHANGING gtt_lines.

  " Format date time.
  gv_date = |{ sy-datum DATE = ENVIRONMENT }|.
  DATA(lv_time) = |{ sy-uzeit TIME = ENVIRONMENT }|.

  TRY. "Creation of Email Body.
      CLEAR gtt_text.
      LOOP AT gtt_lines INTO DATA(lw_lines).
        lo_send_request = cl_bcs=>create_persistent( ).
        REPLACE ALL OCCURRENCES OF '@date@' IN lw_lines WITH gv_date.
        REPLACE ALL OCCURRENCES OF '@time@' IN lw_lines WITH lv_time.
        REPLACE ALL OCCURRENCES OF '@unsuccess@' IN lw_lines WITH gv_fail_count.
        REPLACE ALL OCCURRENCES OF '@success@' IN lw_lines WITH gv_success_count.
        REPLACE ALL OCCURRENCES OF '@exclude@' IN lw_lines WITH lv_exclude.
        gw_text-line = lw_lines.
        APPEND gw_text TO gtt_text.
        CLEAR gw_text.
      ENDLOOP.
*      IF sy-sysid NE 'P03'.
      IF gv_prod EQ abap_false.
        gw_text-line = '<BR></BR>'.
        APPEND gw_text TO gtt_text.
        gw_text-line = | Email sent from { sy-sysid }. |  .
        APPEND gw_text TO gtt_text.
        CLEAR gw_text.
      ENDIF.
      "End of Body.

      TRY. "Adding Subject.
          lo_document = cl_document_bcs=>create_document(
          EXPORTING
          i_type = 'HTM'
          i_text = gtt_text
          i_subject = |{ cv_subject } { gv_date } { lv_time+0(5) }| ).
        CATCH cx_document_bcs INTO go_excep_handler. " BCS: Document Exceptions
          PERFORM exception_handling.
      ENDTRY.

      lo_send_request->set_document( lo_document ).
    CATCH cx_send_req_bcs INTO go_excep_handler.
      PERFORM exception_handling.
  ENDTRY.

*SET ATTACHMENT
  IF gv_fail_count GT 0.
    gv_attach = abap_true.

    "Creating Attachment Header
    CONCATENATE 'RIN'
                'RATE TYPE'
                'ERROR TYPE'
                'ERROR MESSAGE'
                'ERROR DESCRIPTION'
                'ERROR DESCRIPTION'
                'ERROR CODE'
                INTO gv_string
                SEPARATED BY cl_abap_char_utilities=>horizontal_tab.
    gv_data_string = gv_string.

    "Creating Attachment Body
    LOOP AT li_price_calc INTO DATA(wa_price_calc).
      CONCATENATE wa_price_calc-rin
                  wa_price_calc-process_name
                  wa_price_calc-error_type
                  wa_price_calc-error_message
                  wa_price_calc-error_desc
                  wa_price_calc-error_desc1
                  wa_price_calc-error_code
                  INTO gv_string
                  SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

      CONCATENATE gv_data_string gv_string
             INTO gv_data_string
             SEPARATED BY cl_abap_char_utilities=>newline.
    ENDLOOP.
  ENDIF.

*SET ATTACHMENT FOR EXCLUDE.
  IF lv_exclude GT 0.
    gv_excld_attach = abap_true.

    "Creating Attachment Header
    CONCATENATE 'EXCLUDE_RIN'
                'EXCLUDE RATETYPE'
                'EXCLUDE STATUS'
                      INTO gv_string
                      SEPARATED BY cl_abap_char_utilities=>horizontal_tab.
    gv_excld_string = gv_string.

    "Creating Attachment Body
    LOOP AT li_excld INTO DATA(wa_excld).
      CONCATENATE wa_excld-rin
                  wa_excld-ratetype
                  wa_excld-status
                  INTO gv_string
                  SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

      CONCATENATE gv_excld_string gv_string
             INTO gv_excld_string
             SEPARATED BY cl_abap_char_utilities=>newline.
    ENDLOOP.
  ENDIF.

  "Sending email.
  PERFORM send_mail USING gv_data_string
*                          lv_recipient    "Mod-003--
                          gv_recipient_to  "Mod-003++
                          gv_excld_attach gv_excld_string gv_attach
*                          space "Mod-002++ "Mod-003--
                          gv_recipient_cc "Mod-003++
                    CHANGING lv_status.

  CLEAR: gv_recipient_to, gv_recipient_cc. "Mod-003++
ENDFORM.

FORM archive_email TABLES pt_rin STRUCTURE isu_ranges
                    USING
*                          lv_status TYPE abap_bool        "DEL-001++
*                          lv_recipient TYPE ad_smtpadr    "Mod-003--
*                          lv_date TYPE sy-datum           "DEL-001++
                          ps_start TYPE isu_datetime      "INS-001++
                          ps_end   TYPE isu_datetime     "INS-001++
                  CHANGING lv_status TYPE abap_bool.          "INS-001++

  CONSTANTS: lc_subject TYPE char20 VALUE 'ARCHIVE_FAIL',
             lc_text    TYPE char20 VALUE 'ZARCV_ARCV'.

  DATA :
*        lr_date TYPE RANGE OF datum,               "DEL-001++
         lr_rin  TYPE RANGE OF zde_rin.

* Begin of Mod-003++
  gv_recipient_to = 'EMAIL_ARCH_TO'.
  gv_recipient_cc = 'EMAIL_ARCH_CC'.
* End of Mod-003++

  IF pt_rin[] IS NOT INITIAL.
    lr_rin = VALUE #( FOR ls_rin IN pt_rin ( sign = 'I' option = 'EQ' low = ls_rin-low ) ).
  ENDIF.
*----> DEL-001--
*  IF lv_date IS NOT INITIAL.
*    lr_date = VALUE #( ( sign = 'I' option = 'EQ' low = lv_date ) ).
*  ENDIF.
*<---- DEL-001--

  SELECT DISTINCT rin, process_name, error_type, error_message,
    error_desc1, error_code FROM zub_midas_error
    INTO TABLE @DATA(li_arcv) WHERE error_type = @gc_arcv
                                AND status     = @gc_open
*                                AND log_date  IN @lr_date                                "DEL-001++
                                AND log_date BETWEEN @ps_start-date AND @ps_end-date     "INS-001++
                                AND rin       IN @lr_rin.

  " Check and count entries in li_arcv
  gv_fail_count = COND #( WHEN sy-subrc = 0 THEN lines( li_arcv ) ELSE 0 ).

  SELECT DISTINCT rin FROM zub_midas_stats INTO TABLE @DATA(li_arcv_succ)
*    WHERE archive_midas = @sy-datum                                 "DEL-001++
    WHERE archive_midas BETWEEN @ps_start-date AND @ps_end-date     "INS-001++
    AND rin      IN @lr_rin.

  " Check and count entries in li_arcv_succ
  gv_success_count = COND #( WHEN sy-subrc = 0 THEN lines( li_arcv_succ ) ELSE 0 ).

  "Fetching Excluded data from table.
  SELECT * FROM zub_midas_excld
    WHERE rin      IN @lr_rin
      AND status = @gc_open INTO TABLE @DATA(li_excld).

  " Check and count entries in li_excld
  gv_exclude = COND #( WHEN sy-subrc = 0 THEN lines( li_excld ) ELSE 0 ).

  PERFORM mail_body USING lc_text lc_subject.

*SET ATTACHMENT
  IF gv_fail_count GT 0.
    gv_attach = abap_true.
    CONCATENATE 'RIN'
                'RATE TYPE'
                'ERROR TYPE'
                'ERROR MESSAGE'
                'ERROR DESCRIPTION'
                'ERROR CODE'
                      INTO gv_string
                      SEPARATED BY cl_abap_char_utilities=>horizontal_tab.
    gv_data_string = gv_string.

    LOOP AT li_arcv INTO DATA(wa_arcv).
      CONCATENATE wa_arcv-rin
                  wa_arcv-process_name
                  wa_arcv-error_type
                  wa_arcv-error_message
                  wa_arcv-error_desc1
                  wa_arcv-error_code
                  INTO gv_string
                  SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

      CONCATENATE gv_data_string gv_string
             INTO gv_data_string
             SEPARATED BY cl_abap_char_utilities=>newline.
    ENDLOOP.
  ENDIF.
  PERFORM send_mail USING gv_data_string
*                          lv_recipient     "Mod-003--
                          gv_recipient_to   "Mod-003++
                          gv_excld_attach gv_excld_string gv_attach
*                          space "Mod-002++
                          gv_recipient_cc "Mod-003++
                    CHANGING lv_status.

  CLEAR: gv_recipient_to, gv_recipient_cc. "Mod-003++
ENDFORM.

FORM temp_fail_email  USING pv_threshold_temp TYPE string                 "Mod-004++
                            pv_profile_date   TYPE d                        "Mod-004++
*                     USING    pv_recipient TYPE ad_smtpadr      " logic not there in FS  "Mod-003--
                     CHANGING lv_status TYPE abap_bool.          "INS-001++

  CONSTANTS: lc_subject TYPE char20 VALUE 'TEMP_FAIL',
             lc_text    TYPE char20 VALUE 'ZTEMP_TEMP'.

  DATA: lv_so10_text TYPE char20,           "Mod-002++
*        lv_recipient_cc TYPE ad_smtpadr,       "Mod-002++   "Mod-003--
*        lv_recipient    TYPE ad_smtpadr,       "Mod-002++   "Mod-003--
        lv_subject   TYPE char20.           "Mod-002++

* Begin of Mod-004++
  IF NOT pv_threshold_temp IS INITIAL.

*    gv_recipient_to   = 'EMAIL_TEMP2_TO'.            "Mod-005--
    gv_recipient_to   = 'EMAIL_TEMP_TO'.              "Mod-005++
*    gv_recipient_cc   = 'EMAIL_TEMP2_CC'.            "Mod-005--
    gv_recipient_cc   = 'EMAIL_TEMP_CC'.              "Mod-005++
    gv_threshold_temp = pv_threshold_temp.
    lv_so10_text      = 'ZTEMP_NOTIFICATION2'.
    lv_subject        = 'TEMP_NOTICE2'.
    gv_profile_date   = pv_profile_date.

    PERFORM mail_body USING lv_so10_text lv_subject.

    PERFORM send_mail USING gv_data_string
                            gv_recipient_to
                            gv_excld_attach
                            gv_excld_string
                            gv_attach
                            gv_recipient_cc
                      CHANGING lv_status.
    CLEAR: gv_recipient_to, gv_recipient_cc, gv_threshold_temp,
           lv_so10_text, lv_subject, gv_profile_date.
  ELSE.
* End of Mod-004++
    SELECT *
      FROM zub_midas_error
      INTO TABLE @DATA(li_temp_fail)
      WHERE status = @gc_open
      AND error_type = @gc_temp_upld
      AND error_code NE 'E018'.                    "Mod-002++
    IF sy-subrc = 0.
* Begin of Mod-003++
      gv_recipient_to = 'EMAIL_TEMP_TO'.
      gv_recipient_cc = 'EMAIL_TEMP_CC'.
* End of Mod-003++
      gv_profile_date = pv_profile_date."Mod-004++

*    DESCRIBE TABLE li_temp_fail LINES gv_fail_count.
      gv_fail_count = lines( li_temp_fail ).

      PERFORM mail_body USING lc_text lc_subject.
*
*SET ATTACHMENT
      IF gv_fail_count GT 0.
        gv_attach = abap_true.
        CONCATENATE 'ERROR TYPE'
                    'ERROR MESSAGE'
                    'ERROR DESCRIPTION'
                    'ERROR CODE'
                          INTO gv_string
                          SEPARATED BY cl_abap_char_utilities=>horizontal_tab.
        gv_data_string = gv_string.

        LOOP AT li_temp_fail INTO DATA(wa_temp_fail).
          CONCATENATE wa_temp_fail-error_type
                      wa_temp_fail-error_message
                      wa_temp_fail-error_desc1
                      wa_temp_fail-error_code
                      INTO gv_string
                      SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

          CONCATENATE gv_data_string gv_string
                 INTO gv_data_string
                 SEPARATED BY cl_abap_char_utilities=>newline.
        ENDLOOP.
      ENDIF.

      PERFORM send_mail USING gv_data_string
*                            pv_recipient   "Mod-003--
                              gv_recipient_to   "Mod-003++
                              gv_excld_attach gv_excld_string gv_attach
*                            space "Mod-002++
                              gv_recipient_cc "Mod-003++
                        CHANGING lv_status.
      CLEAR: gv_recipient_to, gv_recipient_cc. "Mod-003++
    ENDIF.

* Begin of Mod-002++
    CLEAR:  wa_temp_fail,
            li_temp_fail,
            lo_send_request,
            lo_document,
            gtt_text,
            gw_text,
            go_sender,
            go_recipient,
            go_excep_handler,
            gw_messages,
            gtt_lines.

    SELECT *
      FROM zub_midas_error
      INTO TABLE @li_temp_fail
      WHERE status     EQ @gc_open
      AND   error_type EQ @gc_temp_upld
      AND   error_code EQ 'E018'.
    IF sy-subrc EQ 0.
*    lv_recipient    = 'NOTIFICATION_ID_TO'.      "Mod-003--
*    lv_recipient_cc = 'NOTIFICATION_ID_CC'.      "Mod-003--

* Begin of Mod-003++
*      gv_recipient_to = 'EMAIL_TEMP1_TO'.        "Mod-005--
      gv_recipient_to = 'EMAIL_TEMP_TO'.          "Mod-005++
*      gv_recipient_cc = 'EMAIL_TEMP1_CC'.        "Mod-005--
      gv_recipient_cc = 'EMAIL_TEMP_CC'.          "Mod-005++
* End of Mod-003++

      lv_so10_text    = 'ZTEMP_NOTIFICATION'.
      lv_subject      = 'TEMP_NOTICE'.

      gv_profile_date = pv_profile_date."Mod-004++

      gv_fail_count = lines( li_temp_fail ).

      PERFORM mail_body USING lv_so10_text lv_subject.

*SET ATTACHMENT
      IF gv_fail_count GT 0.
        gv_attach = abap_true.
        CONCATENATE 'ERROR TYPE'
                    'ERROR MESSAGE'
                    'ERROR DESCRIPTION'
                    'ERROR CODE'
                    INTO gv_string
                    SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

        gv_data_string = gv_string.

        LOOP AT li_temp_fail INTO wa_temp_fail.
          CONCATENATE wa_temp_fail-error_type
                      wa_temp_fail-error_message
                      wa_temp_fail-error_desc1
                      wa_temp_fail-error_code
                      INTO gv_string
                      SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

          CONCATENATE gv_data_string
                      gv_string
                      INTO gv_data_string
                      SEPARATED BY cl_abap_char_utilities=>newline.
        ENDLOOP.
      ENDIF.

      PERFORM send_mail USING gv_data_string
*                            lv_recipient   "Mod-003--
                              gv_recipient_to      "Mod-003++
                              gv_excld_attach gv_excld_string gv_attach
                              gv_recipient_cc "Mod-002++
                        CHANGING lv_status.

      CLEAR: gv_recipient_to, gv_recipient_cc. "Mod-003++
    ENDIF.
* End of Mod-002++
  ENDIF. "Mod-004++
ENDFORM.

FORM holiday_email USING
*                         lv_status TYPE abap_bool          "DEL-001++
*                              lv_recipient TYPE ad_smtpadr "Mod-003--
                              lv_success TYPE abap_bool
                  CHANGING lv_status TYPE abap_bool.          "INS-001++

  CONSTANTS: lc_subject   TYPE char20 VALUE 'HOLIDAY_UPLD',
             lc_fail_text TYPE char20 VALUE 'ZHUNS_HOLIDAY',
             lc_succ_text TYPE char20 VALUE 'ZHSUC_HOLIDAY'.

* Begin of Mod-003++
  gv_recipient_to = 'EMAIL_HOLI_TO'.
  gv_recipient_cc = 'EMAIL_HOLI_CC'.
* End of Mod-003++

  "checking in holiday upload is successful or failed.
  IF lv_success = abap_false.
    gv_attach = abap_true.

    "Fetching holiday upload error data.
    SELECT * FROM zub_midas_error INTO TABLE @DATA(li_holiday)
          WHERE error_type EQ @gc_hld_upld AND status EQ @gc_open.

    PERFORM mail_body USING lc_fail_text lc_subject.

*SET ATTACHMENT
    CONCATENATE 'ERROR TYPE'
                'ERROR MESSAGE'
                'ERROR DESCRIPTION'
                'ERROR CODE'
                      INTO gv_string
                      SEPARATED BY cl_abap_char_utilities=>horizontal_tab.
    gv_data_string = gv_string.

    LOOP AT li_holiday INTO DATA(wa_holiday).
      CONCATENATE wa_holiday-error_type
                  wa_holiday-error_message
                  wa_holiday-error_desc1
                  wa_holiday-error_code
                  INTO gv_string
                  SEPARATED BY cl_abap_char_utilities=>horizontal_tab.

      CONCATENATE gv_data_string gv_string
             INTO gv_data_string
             SEPARATED BY cl_abap_char_utilities=>newline.
    ENDLOOP.
  ELSE.
    PERFORM mail_body USING lc_succ_text lc_subject.
  ENDIF.

  PERFORM send_mail USING gv_data_string
*                          lv_recipient     "Mod-003--
                          gv_recipient_to   "Mod-003++
                          gv_excld_attach gv_excld_string gv_attach
*                          space "Mod-002++
                          gv_recipient_cc "Mod-003++
                    CHANGING lv_status.

  CLEAR: gv_recipient_to, gv_recipient_cc. "Mod-003++
ENDFORM.

FORM send_mail USING ls_data_string TYPE string
                    ls_recipient TYPE ad_smtpadr
                    lv_excld_att TYPE abap_bool
                    lv_excld_string TYPE string
                    lv_attach TYPE abap_bool
                    ls_recipient_cc TYPE ad_smtpadr "Mod-002++
               CHANGING cs_status TYPE abap_bool.

  DATA: lw_recipient TYPE ad_smtpadr.

  IF lv_attach = abap_true.

* convert to solix for .csv file.
    TRY.
        cl_bcs_convert=>string_to_solix(
               EXPORTING
                 iv_string   = ls_data_string
                 iv_codepage = '4103'  "suitable for MS Excel, leave empty
                 iv_add_bom  = 'X'     "for other doc types
               IMPORTING
                 et_solix  = DATA(lv_att_content_hex) ).
*                 ev_size   = DATA(lv_size) ).
      CATCH cx_bcs.
        MESSAGE e445(so).
    ENDTRY.

*ADD ATTACHMENT
    CLEAR g_attsubject .
    CONCATENATE 'ERROR_DETAILS' gv_date INTO g_attsubject SEPARATED BY space.

* CREATE ATTACHMENT
    TRY.
        lo_document->add_attachment( EXPORTING
        i_attachment_type = 'CSV'
        i_attachment_subject = g_attsubject
        i_att_content_hex = lv_att_content_hex ).
      CATCH cx_document_bcs INTO go_excep_handler.
        PERFORM exception_handling.
    ENDTRY.
  ENDIF.

*Attachment for Exclude
  IF lv_excld_att = abap_true.
* convert to solix for .csv file.
    TRY.
        cl_bcs_convert=>string_to_solix(
               EXPORTING
                 iv_string   = lv_excld_string
                 iv_codepage = '4103'  "suitable for MS Excel, leave empty
                 iv_add_bom  = 'X'     "for other doc types
               IMPORTING
                 et_solix  = DATA(lv_att_exclude_hex) ).
*                 ev_size   = DATA(lv_size_exclude) ).
      CATCH cx_bcs.
        MESSAGE e445(so).
    ENDTRY.
*ADD ATTACHMENT
    CLEAR g_attsubject .
    CONCATENATE 'EXCLUDE_DETAILS' gv_date INTO g_attsubject SEPARATED BY space.

* CREATE ATTACHMENT
    TRY.
        lo_document->add_attachment( EXPORTING
        i_attachment_type = 'CSV'
        i_attachment_subject = g_attsubject
        i_att_content_hex = lv_att_exclude_hex ).
      CATCH cx_document_bcs INTO go_excep_handler.
        PERFORM exception_handling.
    ENDTRY.
  ENDIF.

  TRY.
      go_sender = cl_sapuser_bcs=>create( sy-uname ). "SENDER IS THE LOGGED IN USER
* SET SENDER TO SEND REQUEST
      TRY.
          lo_send_request->set_sender(
          EXPORTING
          i_sender = go_sender ).
        CATCH cx_send_req_bcs INTO go_excep_handler.
          PERFORM exception_handling.
      ENDTRY.

*catch EXCEPTION here
    CATCH cx_address_bcs INTO go_excep_handler.
      PERFORM exception_handling.
  ENDTRY.

*SET RECIPIENT
  SELECT val_low
    FROM zdbdv_hcode_dtl
    INTO TABLE @DATA(li_recipient)
    WHERE id_type = @gc_idtype
    AND id_num = @gc_idnum
    AND key_name = @ls_recipient.

  LOOP AT li_recipient INTO lw_recipient.
    TRY.
        go_recipient = cl_cam_address_bcs=>create_internet_address( lw_recipient ).
*      CATCH cx_address_bcs.
      CATCH cx_address_bcs INTO go_excep_handler.
        PERFORM exception_handling.
    ENDTRY.

    TRY.
        lo_send_request->add_recipient(
        EXPORTING
        i_recipient = go_recipient
        i_express = 'X' ).
      CATCH cx_send_req_bcs INTO go_excep_handler.
        PERFORM exception_handling.
    ENDTRY.
  ENDLOOP.

* Begin of Mod-002++
  IF ls_recipient_cc IS NOT INITIAL.
    CLEAR: li_recipient, lw_recipient.
    SELECT val_low
      FROM zdbdv_hcode_dtl
      INTO TABLE @li_recipient
      WHERE id_type  EQ @gc_idtype
      AND   id_num   EQ @gc_idnum
      AND   key_name EQ @ls_recipient_cc.
    IF sy-subrc EQ 0.   "Mod-003++
      LOOP AT li_recipient INTO lw_recipient.
        TRY.
            go_recipient = cl_cam_address_bcs=>create_internet_address( lw_recipient ).
          CATCH cx_address_bcs INTO go_excep_handler.
            PERFORM exception_handling.
        ENDTRY.

        TRY.
            lo_send_request->add_recipient(
            EXPORTING
            i_recipient = go_recipient
            i_copy = 'X' ).
          CATCH cx_send_req_bcs INTO go_excep_handler.
            PERFORM exception_handling.
        ENDTRY.
      ENDLOOP.
    ENDIF.    "Mod-003++
  ENDIF.
* End of Mod-002++

  TRY.
      CALL METHOD lo_send_request->set_send_immediately
        EXPORTING
          i_send_immediately = 'X'.
*CATCH EXCEPTION HERE
    CATCH cx_send_req_bcs INTO go_excep_handler.
      PERFORM exception_handling.
  ENDTRY.

*SEND EMAIL
  TRY.
      lo_send_request->send(
      EXPORTING
      i_with_error_screen = 'X' ).
      COMMIT WORK.
      cs_status = abap_true.
*CATCH EXCEPTION HERE
    CATCH cx_send_req_bcs INTO go_excep_handler.
      PERFORM exception_handling.
  ENDTRY.

ENDFORM.

FORM mail_body USING lv_text TYPE char20
                      ls_subject TYPE char20.

  DATA: lv_subject(50)  TYPE c, "Mod-004++
        lv_profile_date TYPE char10. "Mod-004++

  PERFORM call_read_text USING lv_text CHANGING gtt_lines.

  "Formating dat and time.
  WRITE sy-datum TO gv_date DD/MM/YYYY.
  DATA(lv_time) = |{ sy-uzeit TIME = ENVIRONMENT }|.

  TRY. "Creating body for email from SO10 Text.
      CLEAR gtt_text.
      LOOP AT gtt_lines INTO DATA(lw_lines).
        lo_send_request = cl_bcs=>create_persistent( ).
        REPLACE ALL OCCURRENCES OF '@date@' IN lw_lines WITH gv_date.
        REPLACE ALL OCCURRENCES OF '@time@' IN lw_lines WITH lv_time.
        REPLACE ALL OCCURRENCES OF '@unsuccess@' IN lw_lines WITH gv_fail_count.
        REPLACE ALL OCCURRENCES OF '@success@' IN lw_lines WITH gv_success_count.
        REPLACE ALL OCCURRENCES OF '@exclude@' IN lw_lines WITH gv_exclude.
        REPLACE ALL OCCURRENCES OF '@temp@' IN lw_lines WITH gv_threshold_temp.    "Mod-004++
        gw_text-line = lw_lines.
        APPEND gw_text TO gtt_text.
        CLEAR gw_text.
      ENDLOOP.
*      IF sy-sysid NE 'P03'.
      IF gv_prod EQ abap_false.
        gw_text-line = '<BR></BR>'.
        APPEND gw_text TO gtt_text.
        gw_text-line = | Email sent from { sy-sysid }. |  .
        APPEND gw_text TO gtt_text.
        CLEAR gw_text.
      ENDIF.

      SELECT key_name, val_low FROM zdbdv_hcode_dtl INTO TABLE @DATA(li_hcode)
 WHERE id_type = @gc_idtype AND id_num = @gc_idnum.

      IF sy-subrc EQ 0.
        READ TABLE li_hcode ASSIGNING FIELD-SYMBOL(<lfs_subject>) WITH KEY
                                                      key_name = ls_subject.
*        DATA(lv_subject) = <lfs_subject>-val_low.              "Mod-004--
        lv_subject = <lfs_subject>-val_low.                     "Mod-004++
      ENDIF.

* Begin of Mod-004++
      IF ls_subject EQ 'TEMP_NOTICE2'.
        WRITE gv_profile_date TO lv_profile_date DD/MM/YYYY.
        CONCATENATE lv_subject gv_threshold_temp lv_profile_date INTO lv_subject SEPARATED BY space.
      ELSEIF ls_subject EQ 'TEMP_NOTICE'.
        WRITE gv_profile_date TO lv_profile_date DD/MM/YYYY.
        CONCATENATE lv_subject lv_profile_date INTO lv_subject SEPARATED BY space.
      ELSE.
        CONCATENATE lv_subject gv_date lv_time+0(5) INTO lv_subject SEPARATED BY space.
      ENDIF.
* End of Mod-004++

      TRY.
          lo_document = cl_document_bcs=>create_document(
          EXPORTING
          i_type = 'HTM'
          i_text = gtt_text
*          i_subject = |{ lv_subject } { gv_date } { lv_time+0(5) }| ).               "Mod-004--
          i_subject = lv_subject ).                                                   "Mod-004++
        CATCH cx_document_bcs INTO go_excep_handler. " BCS: Document Exceptions
          PERFORM exception_handling.
      ENDTRY.

      lo_send_request->set_document( lo_document ).

    CATCH cx_send_req_bcs INTO go_excep_handler.
      PERFORM exception_handling.
  ENDTRY.

ENDFORM.


FORM call_read_text USING lv_text TYPE char20
                    CHANGING gtt_lines TYPE text_lines.

  SELECT SINGLE tdobject, tdname, tdid, tdspras
   FROM stxh
   INTO @DATA(ls_text)
   WHERE tdobject = 'TEXT' AND  tdname = @lv_text
    AND tdid = 'ST' AND tdspras = @sy-langu.
  IF sy-subrc EQ 0.
    "SAPscript: Read text.
    CALL FUNCTION 'READ_TEXT'
      EXPORTING
        id                      = ls_text-tdid
        language                = ls_text-tdspras
        name                    = ls_text-tdname
        object                  = ls_text-tdobject
      TABLES
        lines                   = gtt_lines
      EXCEPTIONS
        id                      = 1
        language                = 2
        name                    = 3
        not_found               = 4
        object                  = 5
        reference_check         = 6
        wrong_access_to_archive = 7
        OTHERS                  = 8.

    IF sy-subrc <> 0.
*    PERFORM capture_message TABLES gi_messages.
      CLEAR gw_messages.
      gw_messages-type   = sy-msgty.
      gw_messages-id     = sy-msgid.
      gw_messages-number = sy-msgno.
      gw_messages-message_v1 = sy-msgv1.
      gw_messages-message_v2 = sy-msgv2.
      gw_messages-message_v3 = sy-msgv3.
      gw_messages-message_v4 = sy-msgv4.
      APPEND gw_messages TO gi_messages.

      MESSAGE 'Error while fetching the notes details from text'(113) TYPE 'I'.
    ENDIF.
  ENDIF.
ENDFORM.

FORM exception_handling.
  CLEAR gw_messages.
  IF go_excep_handler IS BOUND.
    gw_messages-type = lc_e."'E'.
    gw_messages-message = go_excep_handler->get_text( ).
    APPEND gw_messages TO gi_messages.
*    DATA(ew_message) = gw_messages.
  ELSE.
    MESSAGE 'Mail Sending Failed'(001) TYPE 'E'.
  ENDIF.
ENDFORM.
