REPORT zhr_export_senior_1004.

PARAMETERS:
  p_serv TYPE sapb-sappfad DEFAULT '/tmp/'.

START-OF-SELECTION.

  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho de destino do arquivo no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

*---------------------------------------------------------------------*
FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.
  DATA(vl_strlen) = strlen( p_serv ) - 1.

  IF p_serv IS NOT INITIAL.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_serv '/' INTO p_serv.
    ENDIF.
  ENDIF.

ENDFORM.

*---------------------------------------------------------------------*
FORM f_exportar_dados.

  DATA:
    gv_filename TYPE string,
    gv_header   TYPE string,
    gv_line     TYPE string.

*---------------------------------------------------------------------*
* Arquivo
*---------------------------------------------------------------------*

  gv_filename = p_serv && sy-datum && '_SENIOR_1004.csv'.

  gv_header = 'ESTCAR;CODCAR;TITRED;TITCAR;CODCB2;DATCRI;DATEXT;CNHOBR;OCLOBR;CODSIG'.

*---------------------------------------------------------------------*
* Seleção de Cargos
*---------------------------------------------------------------------*

  SELECT
    t513~stell,          " Código cargo
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

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir arquivo.' TYPE 'E'.
  ENDIF.

  TRANSFER gv_header TO gv_filename.

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

    TRANSFER gv_line TO gv_filename.

  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
