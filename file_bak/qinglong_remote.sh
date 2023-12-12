#!/bin/bash

function sendMessage() {
    echo "$1"
    python3 send.py "执行备份结束" "$1"
}

function file_backup() {
  USER_NAME="${FILE_BACKUP_USER_NAME}"
  USER_KEY_PATH="${FILE_BACKUP_USER_KEY_PATH}"
  HOST_ADDR='10.0.0.3'
  REMOTE_SHELL_PATH=''
  BACKUP_SOURCE_DIR=''
  BACKUP_TARGET_DIR=''

  ZIP_PASSWORD="${FILE_BACKUP_ZIP_PASSWORD}"
  HOST_PORT=22
  MAX_DAYS=3

  if [ -z $USER_NAME ] || [ -z $HOST_ADDR ] || [ -z ${REMOTE_SHELL_PATH} ] || [ -z ${BACKUP_SOURCE_DIR} ] || [ -z ${BACKUP_TARGET_DIR} ]; then
    local result="各参数均不能为空，用户名=[${USER_NAME}], 服务器地址=[${HOST_ADDR}], 服务器脚本=[${REMOTE_SHELL_PATH}], 备份源目录=[${BACKUP_SOURCE_DIR}], 备份目标目录=[${BACKUP_TARGET_DIR}]"
    sendMessage "${result}"
    exit 1;
  fi

  #
  #if [ -z ${USER_NAME}  ]; then
  #  exit 1;
  #fi
  #

  ## 认证方式
  local auth_option=''
  if [ -n "${USER_KEY_PATH}" ]; then
    auth_option=" -i ${USER_KEY_PATH}"
  fi

  local zip_password_option=''
  if [ -n "${ZIP_PASSWORD}" ]; then
      zip_password_option=" -p ${ZIP_PASSWORD}"
  fi

  if [ ${log_level} -le 1 ]; then
    echo "ssh ${USER_NAME}@${HOST_ADDR} ${auth_option} ${REMOTE_SHELL_PATH} -ds ${BACKUP_SOURCE_DIR} -dt ${BACKUP_TARGET_DIR} ${zip_password_option} -l ${MAX_DAYS}"
  fi

  result=$(ssh ${USER_NAME}@${HOST_ADDR} ${auth_option} ${REMOTE_SHELL_PATH} -ds ${BACKUP_SOURCE_DIR} -dt ${BACKUP_TARGET_DIR} ${zip_password_option} -l ${MAX_DAYS} 2>&1)
  sendMessage "${result}"

#  ssh ${USER_NAME}@${HOST_ADDR} ${auth_option} ${REMOTE_SHELL_PATH} -d ${BACKUP_SOURCE_DIR} -f ${BACKUP_TARGET_DIR} ${zip_password_option} -l ${MAX_DAYS}  > output.log 2>&1
#  python3 send.py "执行备份完成" "${result}"
}

log_level=1 #DEBUG=1/INFO=2
file_backup