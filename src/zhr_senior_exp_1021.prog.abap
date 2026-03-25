REPORT zhr_senior_exp_1021.

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

  gv_filename = sy-datum && '_SENIOR_1021.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;EMPATU;CADATU;CODFIL;'
  && 'TIPADM;FICREG;ADMESO'.

*---------------------------------------------------------------------*
* Sele??o (PA0001 + PA0000)
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p1~begda,
    p1~werks,
    p1~btrtl,
    p0~massn,
    p0~massg
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  LEFT JOIN pa0000 AS p0
    ON p0~pernr = p1~pernr
   AND p0~begda = p1~begda.

*---------------------------------------------------------------------*
* Ordena??o
*---------------------------------------------------------------------*

  SORT gt_hist BY pernr begda.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1,
    lv_datalt TYPE char10,
    lv_tipadm TYPE c LENGTH 2,
    lv_admeso TYPE c LENGTH 1,
    lv_ficreg TYPE string.

  SORT gt_hist BY pernr begda werks btrtl.

  DELETE ADJACENT DUPLICATES FROM gt_hist
    COMPARING pernr begda werks btrtl.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).
    DATA: lv_last_werks TYPE werks_d,
          lv_last_btrtl TYPE btrtl.

    AT NEW pernr.
      CLEAR: lv_last_werks, lv_last_btrtl.
    ENDAT.

    IF <fs_hist>-werks = lv_last_werks
     AND <fs_hist>-btrtl = lv_last_btrtl.
      CONTINUE.
    ENDIF.

    lv_last_werks = <fs_hist>-werks.
    lv_last_btrtl = <fs_hist>-btrtl.
*---------------------------------------------------------------------*
* Convers?es
*---------------------------------------------------------------------*

    PERFORM f_conv_tipcol IN PROGRAM zhr_export_senior
      USING <fs_hist>-persg
      CHANGING lv_tipcol.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_hist>-begda
      CHANGING lv_datalt.

*---------------------------------------------------------------------*
* Tipo admiss?o (MASSN/MASSG)
*---------------------------------------------------------------------*

    " TIPADM (2 posi??es)
    PERFORM f_conv_tipadm IN PROGRAM zhr_export_senior
      USING <fs_hist>-massn <fs_hist>-massg
      CHANGING lv_tipadm.

    " ADMESO (1 posi??o)
    PERFORM f_conv_tipadm IN PROGRAM zhr_export_senior
      USING <fs_hist>-massn <fs_hist>-massg
      CHANGING lv_tipadm.

*---------------------------------------------------------------------*
* FICREG (fallback)
*---------------------------------------------------------------------*
    lv_ficreg = <fs_hist>-pernr.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs   && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_datalt         && ';' && " DATALT
      <fs_hist>-werks   && ';' && " EMPATU
      <fs_hist>-btrtl   && ';' && " CADATU
      <fs_hist>-btrtl   && ';' && " CODFIL
      lv_tipadm         && ';' && " TIPADM
      lv_ficreg         && ';' && " FICREG
      lv_admeso.                    " ADMESO

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
