REPORT zhr_senior_exp_1016.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

TYPES: BEGIN OF ty_hist,
         pernr TYPE pernr_d,
         bukrs TYPE bukrs,
         persg TYPE persg,
         begda TYPE begda,
         massn TYPE massn,
         massg TYPE massg,
         mgtxt TYPE t530t-mgtxt,
       END OF ty_hist.

TYPES: BEGIN OF ty_note_map,
         mgtxt  TYPE t530t-mgtxt,
         codnot TYPE n LENGTH 3,
       END OF ty_note_map.

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

  DATA: gt_hist     TYPE STANDARD TABLE OF ty_hist,
        gt_note_map TYPE STANDARD TABLE OF ty_note_map,
        lt_notes    TYPE STANDARD TABLE OF t530t-mgtxt.

  gv_filename = sy-datum && '_SENIOR_1016.csv'.
  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATNOT;TIPNOT;NOTFIC'.

  APPEND gv_header TO gt_file.

  SELECT
    p0~pernr,
    p1~bukrs,
    p1~persg,
    p0~begda,
    p0~massn,
    p0~massg,
    t5~mgtxt
    INTO TABLE @gt_hist
    FROM pa0000 AS p0
    LEFT JOIN pa0001 AS p1
      ON p1~pernr = p0~pernr
     AND p1~begda <= p0~begda
     AND p1~endda >= p0~begda
    LEFT JOIN t530t AS t5
      ON t5~massn = p0~massn
     AND t5~massg = p0~massg
     AND t5~sprsl = @sy-langu
   WHERE p0~begda <= @sy-datum.

  IF gt_hist IS INITIAL.
    PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.
    WRITE: / 'Layout 1016 gerado:', gv_filename.
    RETURN.
  ENDIF.

  SELECT DISTINCT mgtxt
    INTO TABLE @lt_notes
    FROM t530t
   WHERE sprsl = @sy-langu
     AND mgtxt <> @space.

  IF lt_notes IS INITIAL AND sy-langu <> 'P'.
    SELECT DISTINCT mgtxt
      INTO TABLE @lt_notes
      FROM t530t
     WHERE sprsl = 'P'
       AND mgtxt <> @space.
  ENDIF.

  IF lt_notes IS INITIAL.
    SELECT DISTINCT mgtxt
      INTO TABLE @lt_notes
      FROM t530t
     WHERE mgtxt <> @space.
  ENDIF.

  SORT lt_notes BY table_line.
  DELETE ADJACENT DUPLICATES FROM lt_notes COMPARING table_line.

  LOOP AT lt_notes INTO DATA(lv_note_text).
    APPEND VALUE ty_note_map(
      mgtxt  = lv_note_text
      codnot = sy-tabix ) TO gt_note_map.
  ENDLOOP.

  SORT gt_note_map BY mgtxt.
  SORT gt_hist BY pernr begda massn massg.
  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING pernr begda massn massg.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

    DATA: lv_numemp TYPE string,
          lv_tipcol TYPE string,
          lv_numcad TYPE string,
          lv_datnot TYPE string,
          lv_tipnot TYPE string,
          lv_notfic TYPE string.

    IF <fs_hist>-mgtxt IS INITIAL.
      CONTINUE.
    ENDIF.

    READ TABLE gt_note_map ASSIGNING FIELD-SYMBOL(<fs_note_map>)
      WITH KEY mgtxt = <fs_hist>-mgtxt
      BINARY SEARCH.

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_format_date
      USING <fs_hist>-begda
      CHANGING lv_datnot.

    lv_numemp = <fs_hist>-bukrs.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_hist>-bukrs
      CHANGING lv_numemp.
    lv_numcad = |{ <fs_hist>-pernr ALPHA = OUT }|.
    lv_notfic = <fs_hist>-mgtxt.

    IF <fs_note_map> IS ASSIGNED.
      lv_tipnot = <fs_note_map>-codnot.
    ENDIF.

    PERFORM f_fit_field USING lv_numemp 4 CHANGING lv_numemp.
    PERFORM f_fit_field USING lv_tipcol 1 CHANGING lv_tipcol.
    PERFORM f_fit_field USING lv_numcad 9 CHANGING lv_numcad.
    PERFORM f_fit_field USING lv_datnot 10 CHANGING lv_datnot.
    PERFORM f_fit_field USING lv_tipnot 3 CHANGING lv_tipnot.
    PERFORM f_fit_field USING lv_notfic 2500 CHANGING lv_notfic.

    CONCATENATE
      lv_numemp
      lv_tipcol
      lv_numcad
      lv_datnot
      lv_tipnot
      lv_notfic
      INTO gv_line
      SEPARATED BY ';'.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1016 gerado:', gv_filename.

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
  REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab IN pv_text WITH space.
  CONDENSE pv_text.

  IF pv_length > 0
     AND strlen( pv_text ) > pv_length.
    pv_text = pv_text(pv_length).
  ENDIF.

ENDFORM.
