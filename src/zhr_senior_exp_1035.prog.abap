REPORT zhr_senior_exp_1035.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_quota,
         pernr TYPE pernr_d,
         begda TYPE begda,
         endda TYPE endda,
       END OF ty_quota.

TYPES: BEGIN OF ty_vac,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         begda TYPE begda,
         awart TYPE pa2001-awart,
         abwtg TYPE pa2001-abwtg,
       END OF ty_vac.

TYPES: BEGIN OF ty_prog,
         pernr   TYPE pernr_d,
         bukrs   TYPE bukrs,
         persg   TYPE persg,
         iniper  TYPE begda,
         prgdat  TYPE begda,
         prgdfe  TYPE p LENGTH 8 DECIMALS 2,
         prgdab  TYPE p LENGTH 8 DECIMALS 2,
         prgdpg  TYPE datum,
       END OF ty_prog.

TYPES ty_t_quota TYPE STANDARD TABLE OF ty_quota WITH DEFAULT KEY.

DATA gt_quota TYPE STANDARD TABLE OF ty_quota.

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

  DATA: gt_vac   TYPE STANDARD TABLE OF ty_vac,
        gt_prog  TYPE STANDARD TABLE OF ty_prog.

  gv_filename = sy-datum && '_SENIOR_1035.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;INIPER;PRGDAT;PRGDFE;PRGDAB;'
  && 'PRG13S;PRGDPG'.

  APPEND gv_header TO gt_file.

  SELECT pernr, begda, endda
    INTO TABLE @gt_quota
    FROM pa2006.

  SELECT
    p2001~pernr,
    p1~bukrs,
    p1~persg,
    p2001~begda,
    p2001~awart,
    p2001~abwtg
    INTO TABLE @gt_vac
    FROM pa2001 AS p2001
    INNER JOIN pa0001 AS p1
      ON p1~pernr = p2001~pernr
     AND p1~begda <= p2001~begda
     AND p1~endda >= p2001~begda
   WHERE p2001~awart IN ( '0100', '0120', '0130', '0150', '9100', '9120' ).

  SORT gt_quota BY pernr begda DESCENDING endda DESCENDING.
  SORT gt_vac BY pernr begda awart.

  LOOP AT gt_vac ASSIGNING FIELD-SYMBOL(<fs_vac>).

    DATA ls_quota TYPE ty_quota.
    DATA lv_is_abono TYPE c LENGTH 1.
    DATA lv_iniper TYPE datum.
    DATA lv_prgdpg TYPE datum.

    PERFORM f_find_quota
      USING <fs_vac>-pernr <fs_vac>-begda
      CHANGING ls_quota.

    PERFORM f_is_abono_awart USING <fs_vac>-awart CHANGING lv_is_abono.

    lv_iniper = ls_quota-begda.
    IF lv_iniper IS INITIAL.
      lv_iniper = <fs_vac>-begda - 365.
    ENDIF.
    lv_prgdpg = <fs_vac>-begda - 2.

    READ TABLE gt_prog ASSIGNING FIELD-SYMBOL(<fs_prog>)
      WITH KEY pernr  = <fs_vac>-pernr
               iniper = lv_iniper
               prgdat = <fs_vac>-begda
               prgdpg = lv_prgdpg.

    IF sy-subrc <> 0.
      APPEND INITIAL LINE TO gt_prog ASSIGNING <fs_prog>.
      <fs_prog>-pernr  = <fs_vac>-pernr.
      <fs_prog>-bukrs  = <fs_vac>-bukrs.
      <fs_prog>-persg  = <fs_vac>-persg.
      <fs_prog>-iniper = lv_iniper.
      <fs_prog>-prgdat = <fs_vac>-begda.
      <fs_prog>-prgdpg = lv_prgdpg.
    ENDIF.

    IF lv_is_abono = 'X'.
      <fs_prog>-prgdab = <fs_prog>-prgdab + <fs_vac>-abwtg.
    ELSE.
      <fs_prog>-prgdfe = <fs_prog>-prgdfe + <fs_vac>-abwtg.
    ENDIF.

  ENDLOOP.

  LOOP AT gt_prog ASSIGNING <fs_prog>.

    DATA lv_numemp TYPE string.
    DATA lv_tipcol TYPE string.
    DATA lv_numcad TYPE string.
    DATA lv_iniper_txt TYPE string.
    DATA lv_prgdat TYPE string.
    DATA lv_prgdfe TYPE string.
    DATA lv_prgdab TYPE string.
    DATA lv_prg13s TYPE string.
    DATA lv_prgdpg_txt TYPE string.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_prog>-persg
      CHANGING lv_tipcol.

    lv_numemp = <fs_prog>-bukrs.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_prog>-bukrs
      CHANGING lv_numemp.
    lv_numcad = |{ <fs_prog>-pernr ALPHA = OUT }|.
    lv_prg13s = 'N'.

    PERFORM f_format_date USING <fs_prog>-iniper CHANGING lv_iniper_txt.
    PERFORM f_format_date USING <fs_prog>-prgdat CHANGING lv_prgdat.
    PERFORM f_format_date USING <fs_prog>-prgdpg CHANGING lv_prgdpg_txt.
    PERFORM f_format_amount USING <fs_prog>-prgdfe CHANGING lv_prgdfe.
    PERFORM f_format_amount USING <fs_prog>-prgdab CHANGING lv_prgdab.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_iniper_txt 10 CHANGING lv_iniper_txt.
    PERFORM f_fit_field USING lv_prgdat 10 CHANGING lv_prgdat.
    PERFORM f_fit_field USING lv_prgdfe 5 CHANGING lv_prgdfe.
    PERFORM f_fit_field USING lv_prgdab 5 CHANGING lv_prgdab.
    PERFORM f_fit_field USING lv_prg13s 1 CHANGING lv_prg13s.
    PERFORM f_fit_field USING lv_prgdpg_txt 10 CHANGING lv_prgdpg_txt.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_iniper_txt
      lv_prgdat
      lv_prgdfe
      lv_prgdab
      lv_prg13s
      lv_prgdpg_txt
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1035 gerado:', gv_filename.

ENDFORM.

FORM f_find_quota
  USING    pv_pernr TYPE pernr_d
           pv_date  TYPE datum
  CHANGING ps_quota TYPE ty_quota.

  DATA ls_quota TYPE ty_quota.

  CLEAR ps_quota.
  LOOP AT gt_quota INTO ls_quota WHERE pernr = pv_pernr.
    IF ls_quota-begda <= pv_date AND ls_quota-endda >= pv_date.
      ps_quota = ls_quota.
      EXIT.
    ENDIF.
  ENDLOOP.

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
