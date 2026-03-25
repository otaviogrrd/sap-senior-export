REPORT ZHR_SENIOR_EXP_1002.

PARAMETERS: p_path TYPE string OBLIGATORY DEFAULT '/tmp',
            p_file TYPE string LOWER CASE,
            p_head AS CHECKBOX DEFAULT 'X'.

DATA: gv_filename TYPE string,
      gv_header   TYPE string,
      gv_line     TYPE string,
      gv_count    TYPE i.

START-OF-SELECTION.
  PERFORM build_filename.
  PERFORM build_header.
  PERFORM get_data.
  WRITE: / 'Arquivo gerado:', gv_filename.
  WRITE: / 'Registros exportados:', gv_count.

FORM build_filename.
  DATA lv_date TYPE char8.
  DATA lv_time TYPE char6.
  DATA lv_leng TYPE i.
  lv_date = sy-datum.
  lv_time = sy-uzeit.
  gv_filename = p_path.
  lv_leng = strlen( gv_filename ) - 1.
  IF gv_filename+lv_leng(1) <> '/'.
    CONCATENATE gv_filename '/' INTO gv_filename.
  ENDIF.
  IF p_file IS INITIAL.
    CONCATENATE gv_filename 'SENIOR_1002_' lv_date '_' lv_time '.csv' INTO gv_filename.
  ELSE.
    CONCATENATE gv_filename p_file INTO gv_filename.
  ENDIF.
ENDFORM.

FORM build_header.
  gv_header = 'NUMEMP;CODCCU;DESCCCU;NIVCCU;DTINICIO;DTFIM'.
ENDFORM.

FORM get_data.
  OPEN DATASET gv_filename FOR OUTPUT IN TEXT MODE ENCODING DEFAULT WITH SMART LINEFEED.
  IF sy-subrc <> 0.
    MESSAGE |Erro abrindo arquivo { gv_filename }| TYPE 'E'.
  ENDIF.

  IF p_head = 'X'.
    TRANSFER gv_header TO gv_filename.
  ENDIF.

  " TODO: implementar SELECT e mapeamento do layout
  " Exemplo:
  " CLEAR gv_line.
  " CONCATENATE 'VAL1' 'VAL2' INTO gv_line SEPARATED BY ';'.
  " TRANSFER gv_line TO gv_filename.
  " ADD 1 TO gv_count.

  CLOSE DATASET gv_filename.
ENDFORM.
