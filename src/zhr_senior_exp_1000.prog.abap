REPORT zhr_export_senior_1000.

PARAMETERS:
  p_serv   TYPE sapb-sappfad DEFAULT '/tmp/'. " Caminho local para download

START-OF-SELECTION.

  " Verificação dos parâmetros obrigatórios
  IF p_serv IS INITIAL.
    MESSAGE 'Informe o caminho de destino do arquivo no servidor.' TYPE 'E'.
  ENDIF.

  PERFORM f_normalizar_caminhos.
  PERFORM f_exportar_dados.

FORM f_normalizar_caminhos.

  DATA lv_last TYPE c LENGTH 1.

  DATA(vl_strlen) = strlen( p_serv ) - 1.
  " Normalizando o caminho no servidor (p_serv)
  IF p_serv IS NOT INITIAL.
    lv_last = p_serv+vl_strlen(1).
    IF lv_last <> '/'.
      CONCATENATE p_serv '/' INTO p_serv.
    ENDIF.
  ENDIF.

ENDFORM.
FORM f_exportar_dados.

  DATA: gv_filename TYPE string,
        gv_header   TYPE string,
        gv_line     TYPE string.

  gv_filename = p_serv && sy-datum && '_SENIOR_1000.csv'.
  gv_header = 'NUMEMP;NOMEMP;APEEMP;DDITEL;DDDTEL;NUMTEL'.

  SELECT *
    INTO TABLE @DATA(tl_t001)
    FROM t001
   WHERE bukrs LIKE 'BR%'.

  IF sy-subrc NE 0.
    MESSAGE 'Nenhum dado encontrado na tabela SAP.' TYPE 'E'.
  ENDIF.

  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT.

  IF sy-subrc <> 0.
    MESSAGE 'Erro ao abrir o arquivo para gravação.' TYPE 'E'.
  ENDIF.


  TRANSFER gv_header TO gv_filename.

  LOOP AT tl_t001 ASSIGNING FIELD-SYMBOL(<fs_t001>).

    " Criar uma linha para os dados de exportação
    gv_line = <fs_t001>-bukrs && ';' &&
              <fs_t001>-butxt && ';' &&
              <fs_t001>-butxt && ';' &&
              '00' && ';' &&
              '000' && ';' &&
              'N/E' .
*             wl_t001w-telf1 && ';' &&
*             wl_t001w-telf2 && ';' &&
*             wl_t001w-telf3 .

    TRANSFER gv_line TO gv_filename.
  ENDLOOP.

  CLOSE DATASET gv_filename.

  WRITE: / 'Arquivo gerado com sucesso:', gv_filename.

ENDFORM.
