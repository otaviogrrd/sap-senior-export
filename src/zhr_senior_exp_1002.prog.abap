REPORT zhr_senior_exp_1002.

TYPES: BEGIN OF ty_csks,
         bukrs TYPE csks-bukrs,
         kokrs TYPE csks-kokrs,
         kostl TYPE csks-kostl,
         datab TYPE csks-datab,
         datbi TYPE csks-datbi,
       END OF ty_csks,
       BEGIN OF ty_text,
         kokrs TYPE cskt-kokrs,
         kostl TYPE cskt-kostl,
         datbi TYPE cskt-datbi,
         spras TYPE cskt-spras,
         ktext TYPE cskt-ktext,
         prio  TYPE i,
       END OF ty_text,
       BEGIN OF ty_ccu,
         bukrs  TYPE csks-bukrs,
         kostl  TYPE csks-kostl,
         datcri TYPE csks-datab,
         datext TYPE csks-datbi,
         nomccu TYPE cskt-ktext,
       END OF ty_ccu.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

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
        gt_cc       TYPE STANDARD TABLE OF ty_csks,
        gt_text     TYPE STANDARD TABLE OF ty_text,
        gt_ccu      TYPE STANDARD TABLE OF ty_ccu,
        gs_ccu      TYPE ty_ccu,
        gt_file     TYPE STANDARD TABLE OF string.

  DATA: lv_nomccu TYPE string,
        lv_codccu TYPE string,
        lv_datcri TYPE char10,
        lv_datext TYPE char10.

  gv_filename = sy-datum && '_SENIOR_1002.csv'.
  gv_header = 'NUMEMP;CODCCU;NOMCCU;DATCRI;DATEXT'.

  SELECT csks~bukrs,
         csks~kokrs,
         csks~kostl,
         csks~datab,
         csks~datbi
    INTO TABLE @gt_cc
    FROM csks
    INNER JOIN t001
      ON t001~bukrs = csks~bukrs
   WHERE t001~bukrs LIKE 'BR%'.

  IF sy-subrc <> 0 OR gt_cc IS INITIAL.
    MESSAGE 'Nenhum centro de custo encontrado na CSKS.' TYPE 'E'.
  ENDIF.

  SELECT kokrs,
         kostl,
         datbi,
         spras,
         ktext
    INTO TABLE @DATA(lt_cskt)
    FROM cskt
    FOR ALL ENTRIES IN @gt_cc
   WHERE kokrs = @gt_cc-kokrs
     AND kostl = @gt_cc-kostl
     AND datbi = @gt_cc-datbi.

  LOOP AT lt_cskt ASSIGNING FIELD-SYMBOL(<fs_cskt>).
    APPEND INITIAL LINE TO gt_text ASSIGNING FIELD-SYMBOL(<fs_text>).
    MOVE-CORRESPONDING <fs_cskt> TO <fs_text>.

    IF <fs_cskt>-spras = sy-langu.
      <fs_text>-prio = 1.
    ELSEIF <fs_cskt>-spras = 'P'.
      <fs_text>-prio = 2.
    ELSEIF <fs_cskt>-spras = 'E'.
      <fs_text>-prio = 3.
    ELSE.
      <fs_text>-prio = 9.
    ENDIF.
  ENDLOOP.

  SORT gt_text BY kokrs kostl datbi prio ktext.
  DELETE ADJACENT DUPLICATES FROM gt_text COMPARING kokrs kostl datbi.

  SORT gt_cc BY bukrs kostl datbi datab.

  LOOP AT gt_cc ASSIGNING FIELD-SYMBOL(<fs_cc>).

    CLEAR lv_nomccu.

    READ TABLE gt_text ASSIGNING FIELD-SYMBOL(<fs_text_sel>)
      WITH KEY kokrs = <fs_cc>-kokrs
               kostl = <fs_cc>-kostl
               datbi = <fs_cc>-datbi
      BINARY SEARCH.
    IF sy-subrc = 0.
      lv_nomccu = <fs_text_sel>-ktext.
    ENDIF.

    IF gs_ccu-bukrs IS INITIAL
       OR gs_ccu-bukrs <> <fs_cc>-bukrs
       OR gs_ccu-kostl <> <fs_cc>-kostl.

      IF gs_ccu-bukrs IS NOT INITIAL OR gs_ccu-kostl IS NOT INITIAL.
        APPEND gs_ccu TO gt_ccu.
      ENDIF.

      CLEAR gs_ccu.
      gs_ccu-bukrs  = <fs_cc>-bukrs.
      gs_ccu-kostl  = <fs_cc>-kostl.
      gs_ccu-datcri = <fs_cc>-datab.
      gs_ccu-datext = <fs_cc>-datbi.
      gs_ccu-nomccu = lv_nomccu.
      CONTINUE.
    ENDIF.

    IF gs_ccu-datcri IS INITIAL OR <fs_cc>-datab < gs_ccu-datcri.
      gs_ccu-datcri = <fs_cc>-datab.
    ENDIF.

    IF gs_ccu-datext IS INITIAL OR <fs_cc>-datbi > gs_ccu-datext.
      gs_ccu-datext = <fs_cc>-datbi.
      IF lv_nomccu IS NOT INITIAL.
        gs_ccu-nomccu = lv_nomccu.
      ENDIF.
    ELSEIF gs_ccu-nomccu IS INITIAL AND lv_nomccu IS NOT INITIAL.
      gs_ccu-nomccu = lv_nomccu.
    ENDIF.

  ENDLOOP.

  IF gs_ccu-bukrs IS NOT INITIAL OR gs_ccu-kostl IS NOT INITIAL.
    APPEND gs_ccu TO gt_ccu.
  ENDIF.

  APPEND gv_header TO gt_file.

  SORT gt_ccu BY bukrs kostl.

  LOOP AT gt_ccu ASSIGNING FIELD-SYMBOL(<fs_ccu>).

    CLEAR: lv_codccu, lv_nomccu, lv_datcri, lv_datext.

    lv_codccu = <fs_ccu>-kostl.
    lv_codccu = |{ lv_codccu ALPHA = IN }|.

    lv_nomccu = <fs_ccu>-nomccu.
    IF lv_nomccu IS INITIAL.
      lv_nomccu = lv_codccu.
    ENDIF.

    REPLACE ALL OCCURRENCES OF ';' IN lv_nomccu WITH ','.
    REPLACE ALL OCCURRENCES OF
      cl_abap_char_utilities=>cr_lf IN lv_nomccu WITH space.
    REPLACE ALL OCCURRENCES OF
      cl_abap_char_utilities=>newline IN lv_nomccu WITH space.
    CONDENSE lv_nomccu.

    IF <fs_ccu>-datcri IS NOT INITIAL
       AND <fs_ccu>-datcri > '19001231'.
      PERFORM f_conv_date IN PROGRAM zhr_export_senior
        USING <fs_ccu>-datcri
        CHANGING lv_datcri.
    ENDIF.

    IF <fs_ccu>-datext IS NOT INITIAL
       AND <fs_ccu>-datext <> '99991231'
       AND <fs_ccu>-datext < '20800831'.
      PERFORM f_conv_date IN PROGRAM zhr_export_senior
        USING <fs_ccu>-datext
        CHANGING lv_datext.
    ENDIF.

    gv_line =
      <fs_ccu>-bukrs && ';' &&
      lv_codccu      && ';' &&
      lv_nomccu      && ';' &&
      lv_datcri      && ';' &&
      lv_datext.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Layout 1002 gerado:', gv_filename.

ENDFORM.
