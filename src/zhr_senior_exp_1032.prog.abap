REPORT zhr_senior_exp_1032.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_quota,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         begda TYPE begda,
         endda TYPE endda,
         anzhl TYPE pa2006-anzhl,
         kverb TYPE pa2006-kverb,
       END OF ty_quota.

TYPES: BEGIN OF ty_vac,
         pernr TYPE pernr_d,
         begda TYPE begda,
         endda TYPE endda,
         awart TYPE pa2001-awart,
         abwtg TYPE pa2001-abwtg,
       END OF ty_vac.

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

  DATA: gt_quota TYPE STANDARD TABLE OF ty_quota,
        gt_vac   TYPE STANDARD TABLE OF ty_vac.

  gv_filename = sy-datum && '_SENIOR_1032.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;INIPER;FIMPER;QTDDIR;QTDFAL;'
  && 'QTDLIR;QTDAFA;QTDDEB;QTDMIL;QTDABO;QTDSLD;AVOFER;'
  && 'SITPER'.

  APPEND gv_header TO gt_file.

  SELECT
    p6~pernr,
    p1~bukrs,
    p1~persg,
    p6~begda,
    p6~endda,
    p6~anzhl,
    p6~kverb
    INTO TABLE @gt_quota
    FROM pa2006 AS p6
    INNER JOIN pa0001 AS p1
      ON p1~pernr = p6~pernr
     AND p1~begda <= p6~begda
     AND p1~endda >= p6~begda.

  SELECT
    pernr,
    begda,
    endda,
    awart,
    abwtg
    INTO TABLE @gt_vac
    FROM pa2001
   WHERE awart IN ( '0100', '0120', '0130', '0150', '9100', '9120' ).

  SORT gt_quota BY pernr begda endda.
  DELETE ADJACENT DUPLICATES FROM gt_quota COMPARING pernr begda endda anzhl kverb.
  SORT gt_vac BY pernr begda endda awart.

  LOOP AT gt_quota ASSIGNING FIELD-SYMBOL(<fs_quota>).

    DATA: lv_qtddir_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdfal_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdlir_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdafa_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtddeb_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdmil_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdabo_num TYPE p LENGTH 8 DECIMALS 2,
          lv_qtdsld_num TYPE p LENGTH 8 DECIMALS 2.

    DATA lv_has_usage TYPE c LENGTH 1.
    CLEAR lv_has_usage.

    LOOP AT gt_vac ASSIGNING FIELD-SYMBOL(<fs_vac>)
      WHERE pernr = <fs_quota>-pernr
        AND begda >= <fs_quota>-begda
        AND begda <= <fs_quota>-endda.

      lv_has_usage = 'X'.

      DATA lv_is_abono TYPE c LENGTH 1.
      PERFORM f_is_abono_awart
        USING <fs_vac>-awart
        CHANGING lv_is_abono.

      IF lv_is_abono = 'X'.
        lv_qtdabo_num = lv_qtdabo_num + <fs_vac>-abwtg.
      ELSE.
        lv_qtddeb_num = lv_qtddeb_num + <fs_vac>-abwtg.
      ENDIF.

    ENDLOOP.

    IF lv_has_usage IS INITIAL
       AND ( <fs_quota>-endda - <fs_quota>-begda ) < 300.
      CONTINUE.
    ENDIF.

    lv_qtddir_num = <fs_quota>-anzhl.
    lv_qtdfal_num = <fs_quota>-kverb.
    lv_qtdsld_num = lv_qtddir_num - lv_qtddeb_num - lv_qtdabo_num.

    DATA lv_tipcol TYPE string.
    DATA lv_numemp TYPE string.
    DATA lv_numcad TYPE string.
    DATA lv_iniper TYPE string.
    DATA lv_fimper TYPE string.
    DATA lv_qtddir TYPE string.
    DATA lv_qtdfal TYPE string.
    DATA lv_qtdlir TYPE string.
    DATA lv_qtdafa TYPE string.
    DATA lv_qtddeb TYPE string.
    DATA lv_qtdmil TYPE string.
    DATA lv_qtdabo TYPE string.
    DATA lv_qtdsld TYPE string.
    DATA lv_avofer TYPE string.
    DATA lv_sitper TYPE string.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_quota>-persg
      CHANGING lv_tipcol.

    lv_numemp = <fs_quota>-bukrs.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_quota>-bukrs
      CHANGING lv_numemp.
    lv_numcad = |{ <fs_quota>-pernr ALPHA = OUT }|.

    PERFORM f_format_date USING <fs_quota>-begda CHANGING lv_iniper.
    PERFORM f_format_date USING <fs_quota>-endda CHANGING lv_fimper.

    PERFORM f_format_amount USING lv_qtddir_num CHANGING lv_qtddir.
    PERFORM f_format_amount USING lv_qtdfal_num CHANGING lv_qtdfal.
    PERFORM f_format_amount USING lv_qtdlir_num CHANGING lv_qtdlir.
    PERFORM f_format_amount USING lv_qtdafa_num CHANGING lv_qtdafa.
    PERFORM f_format_amount USING lv_qtddeb_num CHANGING lv_qtddeb.
    PERFORM f_format_amount USING lv_qtdmil_num CHANGING lv_qtdmil.
    PERFORM f_format_amount USING lv_qtdabo_num CHANGING lv_qtdabo.
    PERFORM f_format_amount USING lv_qtdsld_num CHANGING lv_qtdsld.

    PERFORM f_calc_avofer
      USING <fs_quota>-begda <fs_quota>-endda
      CHANGING lv_avofer.

    IF lv_qtdsld_num <= 0.
      lv_sitper = '1'.
    ELSE.
      lv_sitper = '0'.
    ENDIF.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_iniper 10 CHANGING lv_iniper.
    PERFORM f_fit_field USING lv_fimper 10 CHANGING lv_fimper.
    PERFORM f_fit_field USING lv_qtddir 6 CHANGING lv_qtddir.
    PERFORM f_fit_field USING lv_qtdfal 7 CHANGING lv_qtdfal.
    PERFORM f_fit_field USING lv_qtdlir 7 CHANGING lv_qtdlir.
    PERFORM f_fit_field USING lv_qtdafa 7 CHANGING lv_qtdafa.
    PERFORM f_fit_field USING lv_qtddeb 6 CHANGING lv_qtddeb.
    PERFORM f_fit_field USING lv_qtdmil 8 CHANGING lv_qtdmil.
    PERFORM f_fit_field USING lv_qtdabo 6 CHANGING lv_qtdabo.
    PERFORM f_fit_field USING lv_qtdsld 8 CHANGING lv_qtdsld.
    PERFORM f_fit_field USING lv_avofer 2 CHANGING lv_avofer.
    PERFORM f_fit_field USING lv_sitper 2 CHANGING lv_sitper.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_iniper
      lv_fimper
      lv_qtddir
      lv_qtdfal
      lv_qtdlir
      lv_qtdafa
      lv_qtddeb
      lv_qtdmil
      lv_qtdabo
      lv_qtdsld
      lv_avofer
      lv_sitper
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1032 gerado:', gv_filename.

ENDFORM.

FORM f_is_abono_awart
  USING    pv_awart TYPE pa2001-awart
  CHANGING pv_flag  TYPE c.

  CLEAR pv_flag.
  IF pv_awart = '0120'
     OR pv_awart = '0130'
     OR pv_awart = '0150'.
    pv_flag = 'X'.
  ENDIF.

ENDFORM.

FORM f_calc_avofer
  USING    pv_begda TYPE datum
           pv_endda TYPE datum
  CHANGING pv_avofer TYPE string.

  DATA: lv_months TYPE i,
        lv_years  TYPE i.

  CLEAR pv_avofer.

  IF pv_begda IS INITIAL OR pv_endda IS INITIAL.
    pv_avofer = '12'.
    RETURN.
  ENDIF.

  lv_years = pv_endda(4) - pv_begda(4).
  lv_months = pv_endda+4(2) - pv_begda+4(2).
  lv_months = ( lv_years * 12 ) + lv_months + 1.

  IF lv_months <= 0 OR lv_months > 12.
    lv_months = 12.
  ENDIF.

  pv_avofer = lv_months.

ENDFORM.

FORM f_format_date
  USING    pv_date TYPE datum
  CHANGING pv_text TYPE string.

  CLEAR pv_text.
  IF pv_date IS INITIAL OR pv_date = '00000000'.
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

  IF pv_length > 0 AND strlen( pv_text ) > pv_length.
    pv_text = pv_text(pv_length).
  ENDIF.

ENDFORM.
