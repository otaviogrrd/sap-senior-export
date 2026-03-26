REPORT zhr_senior_exp_1039.

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

TYPES: BEGIN OF ty_calc,
         bukrs  TYPE bukrs,
         tipcal TYPE c LENGTH 2,
         perref TYPE c LENGTH 7,
         paydt  TYPE pc261-paydt,
         fpbeg  TYPE pc261-fpbeg,
         fpend  TYPE pc261-fpend,
         codcal TYPE n LENGTH 4,
       END OF ty_calc.

TYPES ty_t_asg  TYPE STANDARD TABLE OF ty_asg WITH DEFAULT KEY.
TYPES ty_t_calc TYPE STANDARD TABLE OF ty_calc WITH DEFAULT KEY.

DATA: gt_asg  TYPE STANDARD TABLE OF ty_asg,
      gt_calc TYPE STANDARD TABLE OF ty_calc.

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

  gv_filename = sy-datum && '_SENIOR_1039.csv'.
  gv_header = 'NUMEMP;CODCAL;TIPCAL;PERREF;DATPAG;INICMP;FIMCMP;'
  && 'CODORI;INIAPU;FIMAPU'.

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

  PERFORM f_collect_calculations.

  LOOP AT gt_calc ASSIGNING FIELD-SYMBOL(<fs_calc>).

    DATA: lv_numemp TYPE string,
          lv_codcal TYPE string,
          lv_tipcal TYPE string,
          lv_perref TYPE string,
          lv_datpag TYPE string,
          lv_inicmp TYPE string,
          lv_fimcmp TYPE string,
          lv_codori TYPE string,
          lv_iniapu TYPE string,
          lv_fimapu TYPE string.

    lv_numemp = <fs_calc>-bukrs.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_calc>-bukrs
      CHANGING lv_numemp.
    lv_codcal = <fs_calc>-codcal.
    lv_tipcal = <fs_calc>-tipcal.
    lv_perref = <fs_calc>-perref.
    lv_codori = '0'.

    PERFORM f_format_date USING <fs_calc>-paydt CHANGING lv_datpag.
    PERFORM f_format_date USING <fs_calc>-fpbeg CHANGING lv_inicmp.
    PERFORM f_format_date USING <fs_calc>-fpend CHANGING lv_fimcmp.
    PERFORM f_format_date USING <fs_calc>-fpbeg CHANGING lv_iniapu.
    PERFORM f_format_date USING <fs_calc>-fpend CHANGING lv_fimapu.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_codcal 4 CHANGING lv_codcal.
    PERFORM f_fit_field USING lv_tipcal 2 CHANGING lv_tipcal.
    PERFORM f_fit_field USING lv_perref 7 CHANGING lv_perref.
    PERFORM f_fit_field USING lv_datpag 10 CHANGING lv_datpag.
    PERFORM f_fit_field USING lv_inicmp 10 CHANGING lv_inicmp.
    PERFORM f_fit_field USING lv_fimcmp 10 CHANGING lv_fimcmp.
    PERFORM f_fit_field USING lv_codori 4 CHANGING lv_codori.
    PERFORM f_fit_field USING lv_iniapu 10 CHANGING lv_iniapu.
    PERFORM f_fit_field USING lv_fimapu 10 CHANGING lv_fimapu.

    CONCATENATE
      lv_numemp
      lv_codcal
      lv_tipcal
      lv_perref
      lv_datpag
      lv_inicmp
      lv_fimcmp
      lv_codori
      lv_iniapu
      lv_fimapu
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1039 gerado:', gv_filename.

ENDFORM.

FORM f_collect_calculations
  .

  DATA: lt_pernr TYPE SORTED TABLE OF pernr_d WITH UNIQUE KEY table_line,
        lt_rgdir TYPE STANDARD TABLE OF pc261,
        ls_asg   TYPE ty_asg,
        ls_calc  TYPE ty_calc,
        lv_keydt TYPE datum,
        lv_tipcal TYPE string,
        lv_perref TYPE string,
        lv_codcal TYPE i,
        lv_bukrs  TYPE bukrs.

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

      PERFORM f_determine_tipcal
        USING <fs_rgdir>-ocrsn <fs_rgdir>-occat
        CHANGING lv_tipcal.

      PERFORM f_format_period
        USING <fs_rgdir>-fpend lv_keydt
        CHANGING lv_perref.

      CLEAR ls_calc.
      ls_calc-bukrs  = ls_asg-bukrs.
      ls_calc-tipcal = lv_tipcal.
      ls_calc-perref = lv_perref.
      ls_calc-paydt  = <fs_rgdir>-paydt.
      ls_calc-fpbeg  = <fs_rgdir>-fpbeg.
      ls_calc-fpend  = <fs_rgdir>-fpend.
      APPEND ls_calc TO gt_calc.

    ENDLOOP.
  ENDLOOP.

  SORT gt_calc BY bukrs tipcal perref paydt fpbeg fpend.
  DELETE ADJACENT DUPLICATES FROM gt_calc COMPARING bukrs tipcal perref paydt fpbeg fpend.

  CLEAR: lv_bukrs, lv_codcal.

  LOOP AT gt_calc ASSIGNING FIELD-SYMBOL(<fs_calc>).
    IF <fs_calc>-bukrs <> lv_bukrs.
      lv_bukrs = <fs_calc>-bukrs.
      CLEAR lv_codcal.
    ENDIF.

    ADD 1 TO lv_codcal.
    <fs_calc>-codcal = lv_codcal.
  ENDLOOP.

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
  USING    pv_date   TYPE datum
           pv_fallback TYPE datum
  CHANGING pv_period TYPE string.

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
