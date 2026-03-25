REPORT zhr_senior_exp_1040.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_asg,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         btrtl TYPE btrtl,
         kostl TYPE kostl,
         begda TYPE begda,
         endda TYPE endda,
       END OF ty_asg.

TYPES: BEGIN OF ty_pay,
         pernr  TYPE pernr_d,
         bukrs  TYPE bukrs,
         persg  TYPE persg,
         paydt  TYPE pc261-paydt,
         fpbeg  TYPE pc261-fpbeg,
         fpend  TYPE pc261-fpend,
         seqnr  TYPE pc261-seqnr,
         relid  TYPE pc261-relid,
         tipcal TYPE c LENGTH 2,
         perref TYPE c LENGTH 7,
       END OF ty_pay.

TYPES: BEGIN OF ty_calc,
         bukrs  TYPE bukrs,
         tipcal TYPE c LENGTH 2,
         perref TYPE c LENGTH 7,
         paydt  TYPE pc261-paydt,
         fpbeg  TYPE pc261-fpbeg,
         fpend  TYPE pc261-fpend,
         codcal TYPE n LENGTH 4,
       END OF ty_calc.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_export.

FORM f_export.

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string,
        gt_file     TYPE STANDARD TABLE OF string.

  DATA: gt_asg  TYPE STANDARD TABLE OF ty_asg,
        gt_pay  TYPE STANDARD TABLE OF ty_pay,
        gt_calc TYPE STANDARD TABLE OF ty_calc.

  gv_filename = sy-datum && '_SENIOR_1040.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;CODCAL;TABEVE;CODEVE;REFEVE;'
  && 'VALEVE;TIPCAL;REFREF;DATPAG'.

  APPEND gv_header TO gt_file.

  SELECT
    pernr,
    bukrs,
    persg,
    btrtl,
    kostl,
    begda,
    endda
    INTO TABLE @gt_asg
    FROM pa0001.

  SORT gt_asg BY pernr begda DESCENDING endda DESCENDING.

  PERFORM f_collect_payments
    TABLES gt_asg gt_pay.

  PERFORM f_build_calc_map
    TABLES gt_pay gt_calc.

  SORT gt_calc BY bukrs tipcal perref paydt fpbeg fpend.

  LOOP AT gt_pay ASSIGNING FIELD-SYMBOL(<fs_pay>).

    DATA lt_rt TYPE STANDARD TABLE OF pc207.

    PERFORM f_read_payroll_result
      USING <fs_pay>-pernr <fs_pay>-seqnr <fs_pay>-relid
      CHANGING lt_rt.

    IF lt_rt IS INITIAL.
      CONTINUE.
    ENDIF.

    READ TABLE gt_calc ASSIGNING FIELD-SYMBOL(<fs_calc>)
      WITH KEY bukrs  = <fs_pay>-bukrs
               tipcal = <fs_pay>-tipcal
               perref = <fs_pay>-perref
               paydt  = <fs_pay>-paydt
               fpbeg  = <fs_pay>-fpbeg
               fpend  = <fs_pay>-fpend
      BINARY SEARCH.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    DATA lv_tipcol TYPE string.
    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_pay>-persg
      CHANGING lv_tipcol.

    DATA(lv_numemp) = <fs_pay>-bukrs.
    DATA(lv_numcad) = |{ <fs_pay>-pernr ALPHA = OUT }|.
    DATA(lv_codcal) = |{ <fs_calc>-codcal }|.
    DATA(lv_tabeve) = '1'.
    DATA(lv_tipcal) = <fs_pay>-tipcal.
    DATA(lv_refref) = <fs_pay>-perref.
    DATA(lv_datpag) = ||.

    PERFORM f_format_date USING <fs_pay>-paydt CHANGING lv_datpag.

    LOOP AT lt_rt ASSIGNING FIELD-SYMBOL(<fs_rt>).

      DATA: lv_codeve TYPE string,
            lv_refeve TYPE string,
            lv_valeve TYPE string.

      IF <fs_rt>-betrg IS INITIAL
         AND <fs_rt>-anzhl IS INITIAL.
        CONTINUE.
      ENDIF.

      PERFORM f_wagetype_code
        USING <fs_rt>-lgart
        CHANGING lv_codeve.

      IF lv_codeve IS INITIAL.
        CONTINUE.
      ENDIF.

      PERFORM f_format_amount USING <fs_rt>-anzhl CHANGING lv_refeve.
      PERFORM f_format_amount USING <fs_rt>-betrg CHANGING lv_valeve.

      PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
      PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
      PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
      PERFORM f_fit_field USING lv_codcal 4 CHANGING lv_codcal.
      PERFORM f_fit_field USING lv_tabeve 3 CHANGING lv_tabeve.
      PERFORM f_fit_field USING lv_codeve 4 CHANGING lv_codeve.
      PERFORM f_fit_field USING lv_refeve 12 CHANGING lv_refeve.
      PERFORM f_fit_field USING lv_valeve 12 CHANGING lv_valeve.
      PERFORM f_fit_field USING lv_tipcal 2 CHANGING lv_tipcal.
      PERFORM f_fit_field USING lv_refref 7 CHANGING lv_refref.
      PERFORM f_fit_field USING lv_datpag 10 CHANGING lv_datpag.

      CONCATENATE
        lv_numemp
        lv_tipcol
        lv_numcad
        lv_codcal
        lv_tabeve
        lv_codeve
        lv_refeve
        lv_valeve
        lv_tipcal
        lv_refref
        lv_datpag
        INTO gv_line
        SEPARATED BY ';'.

      APPEND gv_line TO gt_file.

    ENDLOOP.

  ENDLOOP.

  PERFORM f_salvar_arquivo USING gv_filename CHANGING gt_file.

  WRITE: / 'Layout 1040 gerado:', gv_filename.

ENDFORM.

FORM f_collect_payments
  TABLES pt_asg STRUCTURE ty_asg
         pt_pay STRUCTURE ty_pay.

  DATA: lt_pernr TYPE SORTED TABLE OF pernr_d WITH UNIQUE KEY table_line,
        lt_rgdir TYPE STANDARD TABLE OF pc261,
        ls_asg   TYPE ty_asg,
        ls_pay   TYPE ty_pay,
        lv_keydt TYPE datum,
        lv_tipcal TYPE string,
        lv_perref TYPE string.

  LOOP AT pt_asg ASSIGNING FIELD-SYMBOL(<fs_asg>).
    INSERT <fs_asg>-pernr INTO TABLE lt_pernr.
  ENDLOOP.

  LOOP AT lt_pernr INTO DATA(lv_pernr).
    CLEAR lt_rgdir.

    CALL FUNCTION 'CU_READ_RGDIR'
      EXPORTING
        persnr          = lv_pernr
      TABLES
        in_rgdir        = lt_rgdir
      EXCEPTIONS
        no_record_found = 1
        OTHERS          = 2.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    LOOP AT lt_rgdir ASSIGNING FIELD-SYMBOL(<fs_rgdir>)
      WHERE void  = space
        AND srtza = 'A'.

      lv_keydt = <fs_rgdir>-paydt.
      IF lv_keydt IS INITIAL.
        lv_keydt = <fs_rgdir>-fpend.
      ENDIF.
      IF lv_keydt IS INITIAL.
        lv_keydt = <fs_rgdir>-fpbeg.
      ENDIF.

      PERFORM f_get_assignment
        TABLES pt_asg
        USING lv_pernr lv_keydt
        CHANGING ls_asg.

      IF ls_asg-bukrs IS INITIAL.
        CONTINUE.
      ENDIF.

      PERFORM f_determine_tipcal
        USING <fs_rgdir>-ocrsn <fs_rgdir>-occat
        CHANGING lv_tipcal.

      PERFORM f_format_period
        USING <fs_rgdir>-fpend lv_keydt
        CHANGING lv_perref.

      CLEAR ls_pay.
      ls_pay-pernr  = lv_pernr.
      ls_pay-bukrs  = ls_asg-bukrs.
      ls_pay-persg  = ls_asg-persg.
      ls_pay-paydt  = <fs_rgdir>-paydt.
      ls_pay-fpbeg  = <fs_rgdir>-fpbeg.
      ls_pay-fpend  = <fs_rgdir>-fpend.
      ls_pay-seqnr  = <fs_rgdir>-seqnr.
      ls_pay-relid  = <fs_rgdir>-relid.
      ls_pay-tipcal = lv_tipcal.
      ls_pay-perref = lv_perref.
      APPEND ls_pay TO pt_pay.

    ENDLOOP.
  ENDLOOP.

  SORT pt_pay BY pernr seqnr.
  DELETE ADJACENT DUPLICATES FROM pt_pay COMPARING pernr seqnr.

ENDFORM.

FORM f_build_calc_map
  TABLES pt_pay  STRUCTURE ty_pay
         pt_calc STRUCTURE ty_calc.

  DATA lv_codcal TYPE i.
  DATA lv_bukrs  TYPE bukrs.

  LOOP AT pt_pay ASSIGNING FIELD-SYMBOL(<fs_pay>).
    APPEND VALUE ty_calc(
      bukrs  = <fs_pay>-bukrs
      tipcal = <fs_pay>-tipcal
      perref = <fs_pay>-perref
      paydt  = <fs_pay>-paydt
      fpbeg  = <fs_pay>-fpbeg
      fpend  = <fs_pay>-fpend ) TO pt_calc.
  ENDLOOP.

  SORT pt_calc BY bukrs tipcal perref paydt fpbeg fpend.
  DELETE ADJACENT DUPLICATES FROM pt_calc COMPARING bukrs tipcal perref paydt fpbeg fpend.

  CLEAR: lv_bukrs, lv_codcal.

  LOOP AT pt_calc ASSIGNING FIELD-SYMBOL(<fs_calc>).
    IF <fs_calc>-bukrs <> lv_bukrs.
      lv_bukrs = <fs_calc>-bukrs.
      CLEAR lv_codcal.
    ENDIF.
    ADD 1 TO lv_codcal.
    <fs_calc>-codcal = lv_codcal.
  ENDLOOP.

ENDFORM.

FORM f_get_assignment
  TABLES pt_asg STRUCTURE ty_asg
  USING    pv_pernr TYPE pernr_d
           pv_keydt TYPE datum
  CHANGING ps_asg   TYPE ty_asg.

  CLEAR ps_asg.

  LOOP AT pt_asg INTO DATA(ls_asg) WHERE pernr = pv_pernr.
    IF pv_keydt IS INITIAL
       OR ( ls_asg-begda <= pv_keydt AND ls_asg-endda >= pv_keydt ).
      ps_asg = ls_asg.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.

FORM f_determine_tipcal
  USING    pv_ocrsn TYPE pc261-ocrsn
           pv_occat TYPE pc261-occat
  CHANGING pv_tipcal TYPE string.

  IF pv_ocrsn = 'RESC'
     OR pv_occat = '08'.
    pv_tipcal = '15'.
  ELSE.
    pv_tipcal = '11'.
  ENDIF.

ENDFORM.

FORM f_format_period
  USING    pv_date     TYPE datum
           pv_fallback TYPE datum
  CHANGING pv_period   TYPE string.

  DATA lv_date TYPE datum.

  CLEAR pv_period.
  lv_date = pv_date.

  IF lv_date IS INITIAL OR lv_date = '00000000'.
    lv_date = pv_fallback.
  ENDIF.

  IF lv_date IS INITIAL OR lv_date = '00000000'.
    RETURN.
  ENDIF.

  pv_period = |{ lv_date+4(2) }/{ lv_date(4) }|.

ENDFORM.

FORM f_read_payroll_result
  USING    pv_pernr TYPE pernr_d
           pv_seqnr TYPE pc261-seqnr
           pv_relid TYPE pc261-relid
  CHANGING pt_rt    TYPE STANDARD TABLE.

  DATA ls_payroll_result TYPE pay99_result.

  FIELD-SYMBOLS <lt_rt> TYPE STANDARD TABLE.

  CLEAR pt_rt[].

  CALL FUNCTION 'PYXX_READ_PAYROLL_RESULT'
    EXPORTING
      clusterid                    = pv_relid
      employeenumber               = pv_pernr
      sequencenumber               = pv_seqnr
      read_only_international      = 'X'
    CHANGING
      payroll_result               = ls_payroll_result
    EXCEPTIONS
      illegal_isocode_or_clusterid = 1
      error_generating_import      = 2
      import_mismatch_error        = 3
      subpool_dir_full             = 4
      no_read_authority            = 5
      no_record_found              = 6
      versions_do_not_match        = 7
      error_reading_archive        = 8
      error_reading_relid          = 9
      OTHERS                       = 10.

  IF sy-subrc <> 0.
    RETURN.
  ENDIF.

  ASSIGN ls_payroll_result-inter-rt[] TO <lt_rt>.
  IF <lt_rt> IS ASSIGNED.
    pt_rt[] = <lt_rt>[].
  ENDIF.

ENDFORM.

FORM f_wagetype_code
  USING    pv_lgart TYPE lgart
  CHANGING pv_code  TYPE string.

  DATA: lv_digits TYPE string,
        lv_off    TYPE i.

  pv_code = pv_lgart.
  REPLACE ALL OCCURRENCES OF REGEX '[^0-9]' IN pv_code WITH ''.

  lv_digits = pv_code.
  IF lv_digits IS INITIAL.
    CLEAR pv_code.
  ELSEIF strlen( lv_digits ) > 4.
    lv_off = strlen( lv_digits ) - 4.
    pv_code = lv_digits+lv_off(4).
  ELSE.
    pv_code = lv_digits.
  ENDIF.

ENDFORM.

FORM f_format_date
  USING    pv_date TYPE datum
  CHANGING pv_text TYPE string.

  CLEAR pv_text.

  IF pv_date IS INITIAL
     OR pv_date = '00000000'.
    RETURN.
  ENDIF.

  PERFORM f_conv_date IN PROGRAM zhr_export_senior
    USING pv_date
    CHANGING pv_text.

ENDFORM.

FORM f_format_amount
  USING    pv_value TYPE any
  CHANGING pv_text  TYPE string.

  DATA lv_value TYPE p LENGTH 15 DECIMALS 2.

  CLEAR pv_text.
  lv_value = pv_value.

  WRITE lv_value TO pv_text DECIMALS 2 NO-GROUPING.
  CONDENSE pv_text NO-GAPS.
  REPLACE ALL OCCURRENCES OF '.' IN pv_text WITH ','.

ENDFORM.

FORM f_fit_field
  USING    pv_value  TYPE any
           pv_length TYPE i
  CHANGING pv_text   TYPE string.

  pv_text = |{ pv_value }|.
  REPLACE ALL OCCURRENCES OF ';' IN pv_text WITH ','.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN pv_text WITH space.
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline IN pv_text WITH space.
  CONDENSE pv_text.

  IF pv_length > 0
     AND strlen( pv_text ) > pv_length.
    pv_text = pv_text(pv_length).
  ENDIF.

ENDFORM.

FORM f_selecionar_arquivo.

  DATA lv_folder TYPE string.

  CALL METHOD cl_gui_frontend_services=>directory_browse
    CHANGING
      selected_folder      = lv_folder
    EXCEPTIONS
      cntl_error           = 1
      error_no_gui         = 2
      not_supported_by_gui = 3
      OTHERS               = 4.

  IF sy-subrc = 0 AND lv_folder IS NOT INITIAL.
    p_locl = lv_folder.
  ENDIF.

ENDFORM.

FORM f_salvar_arquivo USING pv_filename TYPE string
                     CHANGING pt_file TYPE STANDARD TABLE.

  DATA:
    lv_folder   TYPE string,
    lv_server   TYPE string,
    lv_fullpath TYPE string,
    lv_line     TYPE string.
  DATA:
    lv_last TYPE c LENGTH 1,
    lv_len  TYPE i.

  lv_server = p_serv.

  IF lv_server IS NOT INITIAL.
    lv_len = strlen( lv_server ) - 1.
    IF lv_len >= 0.
      lv_last = lv_server+lv_len(1).
      IF lv_last <> '\' AND lv_last <> '/'.
        CONCATENATE lv_server '/' INTO lv_server.
      ENDIF.
    ENDIF.

    CONCATENATE lv_server pv_filename INTO lv_fullpath.

    OPEN DATASET lv_fullpath FOR OUTPUT
      IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
    IF sy-subrc <> 0.
      MESSAGE 'Erro ao salvar arquivo no servidor.' TYPE 'E'.
    ENDIF.

    LOOP AT pt_file INTO lv_line.
      TRANSFER lv_line TO lv_fullpath.
    ENDLOOP.

    CLOSE DATASET lv_fullpath.
    p_serv = lv_server.
    RETURN.
  ENDIF.

  lv_folder = p_locl.

  IF lv_folder IS INITIAL.
    CALL METHOD cl_gui_frontend_services=>directory_browse
      CHANGING
        selected_folder      = lv_folder
      EXCEPTIONS
        cntl_error           = 1
        error_no_gui         = 2
        not_supported_by_gui = 3
        OTHERS               = 4.

    IF sy-subrc <> 0 OR lv_folder IS INITIAL.
      MESSAGE 'Selecao de diretorio cancelada.' TYPE 'E'.
    ENDIF.
  ENDIF.

  lv_len = strlen( lv_folder ) - 1.
  IF lv_len >= 0.
    lv_last = lv_folder+lv_len(1).
    IF lv_last <> '\' AND lv_last <> '/'.
      CONCATENATE lv_folder '\' INTO lv_folder.
    ENDIF.
  ENDIF.

  CONCATENATE lv_folder pv_filename INTO lv_fullpath.

  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
      filename = lv_fullpath
      filetype = 'ASC'
    TABLES
      data_tab = pt_file
    EXCEPTIONS
      OTHERS   = 1.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao salvar arquivo local.' TYPE 'E'.
  ENDIF.

  p_locl = lv_folder.

ENDFORM.
