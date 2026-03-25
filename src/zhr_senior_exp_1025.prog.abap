REPORT zhr_senior_exp_1025.

PARAMETERS: p_locl TYPE string LOWER CASE,
            p_serv TYPE string LOWER CASE.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_locl.
  PERFORM f_selecionar_arquivo IN PROGRAM zhr_export_senior
    CHANGING p_locl.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_serv.
  PERFORM zf_search_help_directory IN PROGRAM zhr_export_senior
    CHANGING p_serv.

START-OF-SELECTION.

  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1025.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;DATTER;PERINS;PERPER;'
  && 'FATTPO;APOESP'.

*---------------------------------------------------------------------*
* Sele??o (PA0398 + PA0001)
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p398~begda,
    p398~endda,
    p398~insac,
    p398~percc
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  INNER JOIN pa0398 AS p398
    ON p398~pernr = p1~pernr.

*---------------------------------------------------------------------*
* SORT
*---------------------------------------------------------------------*

  SORT gt_hist BY pernr begda insac percc.

*---------------------------------------------------------------------*
* REMOVE DUPLICATES
*---------------------------------------------------------------------*

  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING
    pernr begda insac percc.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* LOOP
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol     TYPE c LENGTH 1,
    lv_datalt     TYPE char10,
    lv_datter     TYPE char10,
    lv_last_insac TYPE pa0398-insac,
    lv_last_percc TYPE pa0398-percc.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

*---------------------------------------------------------------------*
* MUDAN?A REAL
*---------------------------------------------------------------------*

    AT NEW pernr.
      CLEAR: lv_last_insac, lv_last_percc.
    ENDAT.

    IF <fs_hist>-insac = lv_last_insac
     AND <fs_hist>-percc = lv_last_percc.
      CONTINUE.
    ENDIF.

    lv_last_insac = <fs_hist>-insac.
    lv_last_percc = <fs_hist>-percc.

*---------------------------------------------------------------------*
* Ignorar registros sem adicional
*---------------------------------------------------------------------*

    IF <fs_hist>-insac IS INITIAL
       AND <fs_hist>-percc IS INITIAL.
      CONTINUE.
    ENDIF.

*---------------------------------------------------------------------*
* Convers?es
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-begda
      CHANGING lv_datalt.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-endda
      CHANGING lv_datter.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs   && ';' &&
      lv_tipcol         && ';' &&
      <fs_hist>-pernr   && ';' &&
      lv_datalt         && ';' &&
      lv_datter         && ';' &&
      <fs_hist>-insac   && ';' &&
      <fs_hist>-percc   && ';' &&
      '0.00'            && ';' && " FATTPO
      '0'.                          " APOESP

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
