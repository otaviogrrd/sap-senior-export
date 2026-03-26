REPORT zhr_senior_exp_1017.

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

  gv_filename = sy-datum && '_SENIOR_1017.csv'.

  gv_header = 'NUMEMP;TIPCOL;NUMCAD;DATALT;CODCCU'.

*---------------------------------------------------------------------*
* Sele??o hist?rico (PA0001)
*---------------------------------------------------------------------*

  SELECT
    pernr,
    bukrs,
    persg,
    begda,
    kostl
  INTO TABLE @DATA(gt_hist)
  FROM pa0001.

*---------------------------------------------------------------------*
* Ordena??o
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
    lv_datalt TYPE char10,
    lv_kostl  TYPE string.

  SORT gt_hist BY pernr begda kostl.
  DELETE ADJACENT DUPLICATES FROM gt_hist COMPARING pernr begda kostl.

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
* Centro de custo (IMPORTANTE)
*---------------------------------------------------------------------*

    lv_kostl = <fs_hist>-kostl.

    " garantir zeros ? esquerda (formato t?cnico)
    lv_kostl = |{ lv_kostl ALPHA = IN }|.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    DATA(lv_numemp) = ||.
    PERFORM f_map_numemp IN PROGRAM zhr_export_senior
      USING <fs_hist>-bukrs
      CHANGING lv_numemp.

    gv_line =
      lv_numemp         && ';' && " NUMEMP
      lv_tipcol         && ';' && " TIPCOL
      <fs_hist>-pernr   && ';' && " NUMCAD
      lv_datalt         && ';' && " DATALT
      lv_kostl.                     " CODCCU

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
