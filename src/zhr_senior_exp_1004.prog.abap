REPORT zhr_senior_exp_1004.

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

  gv_filename = sy-datum && '_SENIOR_1004.csv'.

  gv_header = 'ESTCAR;CODCAR;TITRED;TITCAR;CODCB2;DATCRI;DATEXT;'
  && 'CNHOBR;OCLOBR;CODSIG'.

*---------------------------------------------------------------------*
* Sele??o de Cargos
*---------------------------------------------------------------------*

  SELECT
    t513~stell,          " C?digo cargo
    t513~begda,
    t513~endda,
    t513s~stltx,         " Texto curto
    t528t~plstx,         " Texto longo
    cbotab~cbo           " CBO

  INTO TABLE @DATA(gt_cargo)

  FROM t513

  LEFT JOIN t513s
    ON t513s~stell = t513~stell
   AND t513s~sprsl = @sy-langu

  LEFT JOIN t528t
    ON t528t~plans = t513~stell
   AND t528t~sprsl = @sy-langu

  LEFT JOIN t7brcb AS cbotab
    ON cbotab~plans = t513~stell

  WHERE t513~endda >= @sy-datum.

*---------------------------------------------------------------------*
* Abrir arquivo
*---------------------------------------------------------------------*

  
  APPEND gv_header TO gt_file.

*---------------------------------------------------------------------*
* Loop
*---------------------------------------------------------------------*

  DATA:
    lv_datcri TYPE char10,
    lv_datext TYPE char10.

  LOOP AT gt_cargo ASSIGNING FIELD-SYMBOL(<fs_cargo>).

*---------------------------------------------------------------------*
* Datas
*---------------------------------------------------------------------*

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_cargo>-begda
      CHANGING lv_datcri.

    PERFORM f_conv_date IN PROGRAM zhr_export_senior
      USING <fs_cargo>-endda
      CHANGING lv_datext.

*---------------------------------------------------------------------*
* Linha
*---------------------------------------------------------------------*

    gv_line =
      '1'               && ';' && " ESTCAR (fixo)
      <fs_cargo>-stell  && ';' && " CODCAR
      <fs_cargo>-stltx  && ';' && " TITRED
      <fs_cargo>-plstx  && ';' && " TITCAR
      <fs_cargo>-cbo    && ';' && " CODCB2
      lv_datcri         && ';' && " DATCRI
      lv_datext         && ';' && " DATEXT
      'N'               && ';' && " CNHOBR (LSimNao)
      'N'               && ';' && " OCLOBR (LSimNao)
      ''.                         " CODSIG

    APPEND gv_line TO gt_file.

  ENDLOOP.

  PERFORM f_salvar_arquivo IN PROGRAM zhr_export_senior USING gv_filename CHANGING gt_file p_locl p_serv.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
