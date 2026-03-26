REPORT zhr_senior_exp_1041.

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
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         btrtl TYPE btrtl,
         kostl TYPE kostl,
         paydt TYPE pc261-paydt,
         fpbeg TYPE pc261-fpbeg,
         fpend TYPE pc261-fpend,
         seqnr TYPE pc261-seqnr,
       END OF ty_pay.

TYPES ty_t_asg TYPE STANDARD TABLE OF ty_asg WITH DEFAULT KEY.
TYPES ty_t_pay TYPE STANDARD TABLE OF ty_pay WITH DEFAULT KEY.

DATA: gt_asg TYPE STANDARD TABLE OF ty_asg,
      gt_pay TYPE STANDARD TABLE OF ty_pay.

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

  gv_filename = sy-datum && '_SENIOR_1041.csv'.
  gv_header = 'NUMEMP;CODFIL;CMPPTE;TIPCOL;NUMCAD;SEQPTE;SRVTER;'
  && 'NRORPA;PERGRP;CODRET;DATPAG;RENBRU;OUTDES;BASINS;'
  && 'DEDINS;BASIRF;IRFRET;VALISS;CODCCU;PERISS;VALLIQ'.

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
    FROM pa0001
   WHERE persg = '6'.

  SORT gt_asg BY pernr begda DESCENDING endda DESCENDING.

  PERFORM f_collect_payments.

  SORT gt_pay BY pernr paydt seqnr.

  DATA: lv_last_pernr TYPE pernr_d,
        lv_last_paydt TYPE pc261-paydt,
        lv_seqpte_i   TYPE i.

  LOOP AT gt_pay ASSIGNING FIELD-SYMBOL(<fs_pay>).

    DATA lt_rt TYPE STANDARD TABLE OF pc207.

    PERFORM f_read_payroll_result
      USING <fs_pay>-pernr <fs_pay>-seqnr
      CHANGING lt_rt.

    IF lt_rt IS INITIAL.
      CONTINUE.
    ENDIF.

    IF <fs_pay>-pernr <> lv_last_pernr
       OR <fs_pay>-paydt <> lv_last_paydt.
      lv_last_pernr = <fs_pay>-pernr.
      lv_last_paydt = <fs_pay>-paydt.
      CLEAR lv_seqpte_i.
    ENDIF.
    ADD 1 TO lv_seqpte_i.

    DATA lv_tipcol TYPE string.
    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_pay>-persg
      CHANGING lv_tipcol.

    IF lv_tipcol <> '2'.
      CONTINUE.
    ENDIF.

    DATA: lv_renbru_num TYPE p LENGTH 15 DECIMALS 2,
          lv_outdes_num TYPE p LENGTH 15 DECIMALS 2,
          lv_basins_num TYPE p LENGTH 15 DECIMALS 2,
          lv_dedins_num TYPE p LENGTH 15 DECIMALS 2,
          lv_basirf_num TYPE p LENGTH 15 DECIMALS 2,
          lv_irfret_num TYPE p LENGTH 15 DECIMALS 2,
          lv_valiss_num TYPE p LENGTH 15 DECIMALS 2,
          lv_periss_num TYPE p LENGTH 7 DECIMALS 2,
          lv_valliq_num TYPE p LENGTH 15 DECIMALS 2.

    LOOP AT lt_rt ASSIGNING FIELD-SYMBOL(<fs_rt>).
      IF <fs_rt>-betrg > 0.
        lv_renbru_num = lv_renbru_num + <fs_rt>-betrg.
      ELSEIF <fs_rt>-betrg < 0.
        lv_outdes_num = lv_outdes_num + ( <fs_rt>-betrg * -1 ).
      ENDIF.
    ENDLOOP.

    IF lv_renbru_num IS INITIAL
       AND lv_outdes_num IS INITIAL.
      CONTINUE.
    ENDIF.

    lv_basins_num = lv_renbru_num.
    lv_basirf_num = lv_renbru_num.
    lv_valliq_num = lv_renbru_num - lv_outdes_num.

    DATA: lv_numemp TYPE string,
          lv_codfil TYPE string,
          lv_cmppte TYPE string,
          lv_numcad TYPE string,
          lv_seqpte TYPE string,
          lv_srvter TYPE string,
          lv_nrorpa TYPE string,
          lv_pergrp TYPE string,
          lv_codret TYPE string,
          lv_datpag TYPE string,
          lv_renbru TYPE string,
          lv_outdes TYPE string,
          lv_basins TYPE string,
          lv_dedins TYPE string,
          lv_basirf TYPE string,
          lv_irfret TYPE string,
          lv_valiss TYPE string,
          lv_codccu TYPE string,
          lv_periss TYPE string,
          lv_valliq TYPE string.

    lv_numemp = <fs_pay>-bukrs.
    lv_codfil = <fs_pay>-btrtl.
    lv_numcad = |{ <fs_pay>-pernr ALPHA = OUT }|.
    lv_seqpte = |{ lv_seqpte_i }|.
    lv_srvter = 'PAGAMENTO DE TERCEIRO'.
    lv_codccu = <fs_pay>-kostl.

    PERFORM f_format_period USING <fs_pay>-paydt <fs_pay>-fpend CHANGING lv_cmppte.
    PERFORM f_format_date USING <fs_pay>-paydt CHANGING lv_datpag.
    PERFORM f_format_amount USING lv_renbru_num CHANGING lv_renbru.
    PERFORM f_format_amount USING lv_outdes_num CHANGING lv_outdes.
    PERFORM f_format_amount USING lv_basins_num CHANGING lv_basins.
    PERFORM f_format_amount USING lv_dedins_num CHANGING lv_dedins.
    PERFORM f_format_amount USING lv_basirf_num CHANGING lv_basirf.
    PERFORM f_format_amount USING lv_irfret_num CHANGING lv_irfret.
    PERFORM f_format_amount USING lv_valiss_num CHANGING lv_valiss.
    PERFORM f_format_amount USING lv_periss_num CHANGING lv_periss.
    PERFORM f_format_amount USING lv_valliq_num CHANGING lv_valliq.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_codfil 6 CHANGING lv_codfil.
    PERFORM f_fit_field USING lv_cmppte 7 CHANGING lv_cmppte.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_seqpte 3 CHANGING lv_seqpte.
    PERFORM f_fit_field USING lv_srvter 249 CHANGING lv_srvter.
    PERFORM f_fit_field USING lv_nrorpa 9 CHANGING lv_nrorpa.
    PERFORM f_fit_field USING lv_pergrp 5 CHANGING lv_pergrp.
    PERFORM f_fit_field USING lv_codret 4 CHANGING lv_codret.
    PERFORM f_fit_field USING lv_datpag 10 CHANGING lv_datpag.
    PERFORM f_fit_field USING lv_renbru 12 CHANGING lv_renbru.
    PERFORM f_fit_field USING lv_outdes 12 CHANGING lv_outdes.
    PERFORM f_fit_field USING lv_basins 12 CHANGING lv_basins.
    PERFORM f_fit_field USING lv_dedins 12 CHANGING lv_dedins.
    PERFORM f_fit_field USING lv_basirf 12 CHANGING lv_basirf.
    PERFORM f_fit_field USING lv_irfret 12 CHANGING lv_irfret.
    PERFORM f_fit_field USING lv_valiss 12 CHANGING lv_valiss.
    PERFORM f_fit_field USING lv_codccu 18 CHANGING lv_codccu.
    PERFORM f_fit_field USING lv_periss 5 CHANGING lv_periss.
    PERFORM f_fit_field USING lv_valliq 13 CHANGING lv_valliq.

    CONCATENATE
      lv_numemp
      lv_codfil
      lv_cmppte
      lv_tipcol
      lv_numcad
      lv_seqpte
      lv_srvter
      lv_nrorpa
      lv_pergrp
      lv_codret
      lv_datpag
      lv_renbru
      lv_outdes
      lv_basins
      lv_dedins
      lv_basirf
      lv_irfret
      lv_valiss
      lv_codccu
      lv_periss
      lv_valliq
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1041 gerado:', gv_filename.

ENDFORM.

FORM f_collect_payments
  .

  DATA: lt_pernr TYPE SORTED TABLE OF pernr_d WITH UNIQUE KEY table_line,
        lt_rgdir TYPE STANDARD TABLE OF pc261,
        ls_asg   TYPE ty_asg,
        ls_pay   TYPE ty_pay,
        lv_keydt TYPE datum.

  LOOP AT gt_asg ASSIGNING FIELD-SYMBOL(<fs_asg>).
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
        USING lv_pernr lv_keydt
        CHANGING ls_asg.

      IF ls_asg-bukrs IS INITIAL.
        CONTINUE.
      ENDIF.

      CLEAR ls_pay.
      ls_pay-pernr = lv_pernr.
      ls_pay-bukrs = ls_asg-bukrs.
      ls_pay-persg = ls_asg-persg.
      ls_pay-btrtl = ls_asg-btrtl.
      ls_pay-kostl = ls_asg-kostl.
      ls_pay-paydt = <fs_rgdir>-paydt.
      ls_pay-fpbeg = <fs_rgdir>-fpbeg.
      ls_pay-fpend = <fs_rgdir>-fpend.
      ls_pay-seqnr = <fs_rgdir>-seqnr.
      APPEND ls_pay TO gt_pay.

    ENDLOOP.
  ENDLOOP.

  SORT gt_pay BY pernr seqnr.
  DELETE ADJACENT DUPLICATES FROM gt_pay COMPARING pernr seqnr.

ENDFORM.

FORM f_get_assignment
  USING    pv_pernr TYPE pernr_d
           pv_keydt TYPE datum
  CHANGING ps_asg   TYPE ty_asg.

  CLEAR ps_asg.

  LOOP AT gt_asg INTO DATA(ls_asg) WHERE pernr = pv_pernr.
    IF pv_keydt IS INITIAL
       OR ( ls_asg-begda <= pv_keydt AND ls_asg-endda >= pv_keydt ).
      ps_asg = ls_asg.
      EXIT.
    ENDIF.
  ENDLOOP.

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

  DATA: lv_value TYPE p LENGTH 15 DECIMALS 2,
        lv_text  TYPE c LENGTH 40.

  CLEAR pv_text.
  CLEAR lv_text.
  lv_value = pv_value.

  WRITE lv_value TO lv_text DECIMALS 2 NO-GROUPING.
  CONDENSE lv_text NO-GAPS.
  REPLACE ALL OCCURRENCES OF '.' IN lv_text WITH ','.
  pv_text = lv_text.

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
