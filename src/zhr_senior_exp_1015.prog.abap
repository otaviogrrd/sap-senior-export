REPORT zhr_senior_exp_1015.

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

  gv_filename = sy-datum && '_SENIOR_1015.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;ESTCAR;CODCAR;CODMOT'.

*---------------------------------------------------------------------*
* Sele??o hist?rico (PA0001)
*---------------------------------------------------------------------*

  SELECT
    p1~pernr,
    p1~bukrs,
    p1~persg,
    p1~begda,
    p1~stell,
    p0~massn,
    p0~massg
  INTO TABLE @DATA(gt_hist)
  FROM pa0001 AS p1
  LEFT JOIN pa0000 AS p0
    ON p0~pernr EQ p1~pernr
   AND p0~begda LE  p1~begda
   AND p0~endda GE  p1~begda.

*---------------------------------------------------------------------*
* Ordenar hist?rico
*---------------------------------------------------------------------*

  SORT gt_hist BY pernr begda.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_tipcol TYPE c LENGTH 1,
    lv_datalt TYPE char10.

  LOOP AT gt_hist ASSIGNING FIELD-SYMBOL(<fs_hist>).

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
* Linha
*---------------------------------------------------------------------*

    gv_line =
      <fs_hist>-bukrs    && ';' && " NUMEMP
      lv_tipcol          && ';' && " TIPCOL
      <fs_hist>-pernr    && ';' && " NUMCAD
      lv_datalt          && ';' && " DATALT
      '1'                && ';' && " ESTCAR (fixo)
      <fs_hist>-stell    && ';' && " CODCAR
      <fs_hist>-massg.               " CODMOT

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
