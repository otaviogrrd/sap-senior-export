REPORT zhr_senior_exp_1008.

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

  gv_filename = sy-datum && '_SENIOR_1008.csv'.

  gv_header = 'CODBAN;CODAGE;NOMAGE;CODEST;CODCID;DIGAGE'.

*---------------------------------------------------------------------*
* Coletar dados do empregado (origem real das ag?ncias)
*---------------------------------------------------------------------*

  SELECT DISTINCT
    bankl
  INTO TABLE @DATA(gt_bankl)
  FROM pa0009
  WHERE bankl NE ''.

*---------------------------------------------------------------------*
* Ordenar e evitar duplicidade
*---------------------------------------------------------------------*

  SORT gt_bankl BY bankl.
  DELETE ADJACENT DUPLICATES FROM gt_bankl COMPARING bankl.

*---------------------------------------------------------------------*
* Buscar dados do banco
*---------------------------------------------------------------------*

  SELECT
    bankl,
    banka,
    ort01,
    provz
  INTO TABLE @DATA(gt_bnka)
  FROM bnka
  FOR ALL ENTRIES IN @gt_bankl
  WHERE bankl = @gt_bankl-bankl
    AND banks = 'BR'.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  LOOP AT gt_bankl ASSIGNING FIELD-SYMBOL(<fs_bank>).

    DATA: lv_codban TYPE string,
          lv_codage TYPE string,
          lv_nome   TYPE string,
          lv_estado TYPE string,
          lv_cidade TYPE string,
          lv_dig    TYPE string.

*---------------------------------------------------------------------*
* Banco / Ag?ncia
*---------------------------------------------------------------------*

    lv_codban = <fs_bank>-bankl(3).
    lv_codage = <fs_bank>-bankl+3.

*---------------------------------------------------------------------*
* Buscar dados BNKA
*---------------------------------------------------------------------*

    READ TABLE gt_bnka ASSIGNING FIELD-SYMBOL(<fs_bnka>)
      WITH KEY bankl = <fs_bank>-bankl.

    IF sy-subrc = 0.
      lv_nome   = <fs_bnka>-banka. " fallback
      lv_estado = <fs_bnka>-PROVZ.
      lv_cidade = <fs_bnka>-ort01.
    ENDIF.

*---------------------------------------------------------------------*
* Ajustes
*---------------------------------------------------------------------*

    IF lv_nome IS INITIAL.
      lv_nome = 'AGENCIA'.
    ENDIF.

    lv_dig = ''. " n?o existe no SAP

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      lv_codban && ';' && " CODBAN
      lv_codage && ';' && " CODAGE
      lv_nome   && ';' && " NOMAGE
      lv_estado && ';' && " CODEST
      lv_cidade && ';' && " CODCID (precisa convers?o IBGE)
      lv_dig.             " DIGAGE

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo 1008 gerado:', gv_filename.

ENDFORM.
