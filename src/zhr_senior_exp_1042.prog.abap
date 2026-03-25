REPORT zhr_senior_exp_1042.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_asg,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         begda TYPE begda,
         endda TYPE endda,
       END OF ty_asg.

TYPES: BEGIN OF ty_dep,
         pernr  TYPE pernr_d,
         coddep TYPE pa0021-subty,
       END OF ty_dep.

TYPES: BEGIN OF ty_pay,
         pernr  TYPE pernr_d,
         bukrs  TYPE bukrs,
         persg  TYPE persg,
         paydt  TYPE pc261-paydt,
         fpbeg  TYPE pc261-fpbeg,
         fpend  TYPE pc261-fpend,
         seqnr  TYPE pc261-seqnr,
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

TYPES: BEGIN OF ty_wtext,
         lgart TYPE lgart,
         lgtxt TYPE string,
       END OF ty_wtext.

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

  DATA: gt_asg   TYPE STANDARD TABLE OF ty_asg,
        gt_dep   TYPE STANDARD TABLE OF ty_dep,
        gt_pay   TYPE STANDARD TABLE OF ty_pay,
        gt_calc  TYPE STANDARD TABLE OF ty_calc,
        gt_wtext TYPE STANDARD TABLE OF ty_wtext.

  gv_filename = sy-datum && '_SENIOR_1042.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;CODDEP;SEQPAG;ORIPEN;TIPPEN;'
  && 'DATRF1;DATRF2;CODCAL;BASPEN;VALPEN;DATRF3'.

  APPEND gv_header TO gt_file.

  SELECT
    pernr,
    bukrs,
    persg,
    begda,
    endda
    INTO TABLE @gt_asg
    FROM pa0001.

  SELECT
    pernr,
    subty
    INTO TABLE @gt_dep
    FROM pa0021
   WHERE begda <= @sy-datum
     AND endda >= @sy-datum.

  SELECT
    lgart,
    lgtxt
    INTO TABLE @gt_wtext
    FROM t512t
   WHERE sprsl = @sy-langu.

  SORT gt_asg BY pernr begda DESCENDING endda DESCENDING.
  SORT gt_dep BY pernr coddep.
  DELETE ADJACENT DUPLICATES FROM gt_dep COMPARING pernr coddep.
  SORT gt_wtext BY lgart.
  DELETE ADJACENT DUPLICATES FROM gt_wtext COMPARING lgart.

  PERFORM f_collect_payments
    TABLES gt_asg gt_pay.

  PERFORM f_build_calc_map
    TABLES gt_pay gt_calc.

  SORT gt_calc BY bukrs tipcal perref paydt fpbeg fpend.

  DATA: lv_last_pernr TYPE pernr_d,
        lv_last_paydt TYPE pc261-paydt,
        lv_seqpag_i   TYPE i.

  LOOP AT gt_pay ASSIGNING FIELD-SYMBOL(<fs_pay>).

    DATA lt_rt TYPE STANDARD TABLE OF pc207.

    PERFORM f_read_payroll_result
      USING <fs_pay>-pernr <fs_pay>-seqnr
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

    IF <fs_pay>-pernr <> lv_last_pernr
       OR <fs_pay>-paydt <> lv_last_paydt.
      lv_last_pernr = <fs_pay>-pernr.
      lv_last_paydt = <fs_pay>-paydt.
      CLEAR lv_seqpag_i.
    ENDIF.

    DATA lv_tipcol TYPE string.
    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_pay>-persg
      CHANGING lv_tipcol.

    DATA(lv_numemp) = <fs_pay>-bukrs.
    DATA(lv_numcad) = |{ <fs_pay>-pernr ALPHA = OUT }|.
    DATA(lv_coddep) = '1'.

    READ TABLE gt_dep ASSIGNING FIELD-SYMBOL(<fs_dep>)
      WITH KEY pernr = <fs_pay>-pernr
      BINARY SEARCH.

    IF sy-subrc = 0.
      lv_coddep = <fs_dep>-coddep.
    ENDIF.

    LOOP AT lt_rt ASSIGNING FIELD-SYMBOL(<fs_rt>).

      DATA lv_text TYPE string.
      READ TABLE gt_wtext ASSIGNING FIELD-SYMBOL(<fs_wtext>)
        WITH KEY lgart = <fs_rt>-lgart
        BINARY SEARCH.
      IF sy-subrc = 0.
        lv_text = <fs_wtext>-lgtxt.
      ENDIF.

      DATA lv_is_pension TYPE abap_bool.
      PERFORM f_is_pension_text
        USING lv_text
        CHANGING lv_is_pension.

      IF lv_is_pension <> abap_true.
        CONTINUE.
      ENDIF.

      ADD 1 TO lv_seqpag_i.

      DATA: lv_oripen TYPE string,
            lv_tippen TYPE string,
            lv_datrf1 TYPE string,
            lv_datrf2 TYPE string,
            lv_datrf3 TYPE string,
            lv_codcal TYPE string,
            lv_baspen TYPE string,
            lv_valpen TYPE string,
            lv_valpen_num TYPE p LENGTH 15 DECIMALS 2.

      IF <fs_pay>-tipcal = '15'.
        lv_oripen = 'R'.
      ELSE.
        lv_oripen = 'C'.
      ENDIF.

      lv_tippen = 'N'.
      lv_codcal = |{ <fs_calc>-codcal }|.

      lv_valpen_num = <fs_rt>-betrg.
      IF lv_valpen_num < 0.
        lv_valpen_num = lv_valpen_num * -1.
      ENDIF.

      PERFORM f_format_date USING <fs_pay>-fpbeg CHANGING lv_datrf1.
      PERFORM f_format_date USING <fs_pay>-fpend CHANGING lv_datrf2.
      PERFORM f_format_date USING <fs_pay>-paydt CHANGING lv_datrf3.
      PERFORM f_format_amount USING lv_valpen_num CHANGING lv_baspen.
      PERFORM f_format_amount USING lv_valpen_num CHANGING lv_valpen.

      DATA(lv_seqpag) = |{ lv_seqpag_i }|.

      PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
      PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
      PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
      PERFORM f_fit_field USING lv_coddep 2 CHANGING lv_coddep.
      PERFORM f_fit_field USING lv_seqpag 3 CHANGING lv_seqpag.
      PERFORM f_fit_field USING lv_oripen 1 CHANGING lv_oripen.
      PERFORM f_fit_field USING lv_tippen 1 CHANGING lv_tippen.
      PERFORM f_fit_field USING lv_datrf1 10 CHANGING lv_datrf1.
      PERFORM f_fit_field USING lv_datrf2 10 CHANGING lv_datrf2.
      PERFORM f_fit_field USING lv_codcal 4 CHANGING lv_codcal.
      PERFORM f_fit_field USING lv_baspen 12 CHANGING lv_baspen.
      PERFORM f_fit_field USING lv_valpen 12 CHANGING lv_valpen.
      PERFORM f_fit_field USING lv_datrf3 10 CHANGING lv_datrf3.

      CONCATENATE
        lv_numemp
        lv_tipcol
        lv_numcad
        lv_coddep
        lv_seqpag
        lv_oripen
        lv_tippen
        lv_datrf1
        lv_datrf2
        lv_codcal
        lv_baspen
        lv_valpen
        lv_datrf3
        INTO gv_line
        SEPARATED BY ';'.

      APPEND gv_line TO gt_file.

    ENDLOOP.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1042 gerado:', gv_filename.

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

FORM f_is_pension_text
  USING    pv_text TYPE string
  CHANGING pv_flag TYPE abap_bool.

  DATA lv_text TYPE string.

  pv_flag = abap_false.
  lv_text = pv_text.
  TRANSLATE lv_text TO UPPER CASE.

  IF lv_text CS 'PENS'
     OR lv_text CS 'ALIMENT'
     OR lv_text CS 'JUDIC'.
    pv_flag = abap_true.
  ENDIF.

ENDFORM.

FORM f_read_payroll_result
  USING    pv_pernr TYPE pernr_d
           pv_seqnr TYPE pc261-seqnr
  CHANGING pt_rt    TYPE STANDARD TABLE.

  DATA ls_payroll_result TYPE pay99_result.

  FIELD-SYMBOLS <lt_rt> TYPE STANDARD TABLE.

  CLEAR pt_rt[].

  CALL FUNCTION 'PYXX_READ_PAYROLL_RESULT'
    EXPORTING
      clusterid                    = 'RX'
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

FORM f_format_period
  USING    pv_date     TYPE datum
           pv_fallback TYPE datum
  CHANGING pv_period   TYPE string.

  DATA lv_date TYPE datum.

  lv_date = pv_date.
  IF lv_date IS INITIAL OR lv_date = '00000000'.
    lv_date = pv_fallback.
  ENDIF.

  CLEAR pv_period.
  IF lv_date IS INITIAL OR lv_date = '00000000'.
    RETURN.
  ENDIF.

  pv_period = |{ lv_date+4(2) }/{ lv_date(4) }|.

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
