REPORT zhr_senior_exp_1007.

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

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string,
    gt_file     TYPE STANDARD TABLE OF string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = sy-datum && '_SENIOR_1007.csv'.

  gv_header = 'CODBAN;NOMBAN'.

*---------------------------------------------------------------------*
* Select bancos
*---------------------------------------------------------------------*

  SELECT DISTINCT
    bankl,
    banka
  INTO TABLE @DATA(gt_bnka)
  FROM bnka
  WHERE banks = 'BR'.

*---------------------------------------------------------------------*
* Ordenar
*---------------------------------------------------------------------*

  SORT gt_bnka BY bankl.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  LOOP AT gt_bnka ASSIGNING FIELD-SYMBOL(<fs_bnka>).

    DATA(lv_codban) = <fs_bnka>-bankl.
    DATA(lv_nome)   = <fs_bnka>-banka.

    gv_line =
      lv_codban && ';' &&
      lv_nome.

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo 1007 gerado:', gv_filename.

ENDFORM.
