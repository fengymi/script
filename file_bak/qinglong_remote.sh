#!/bin/bash

## 登录用户名
#FILE_BACKUP_USER_NAME
## 用户ssh认证文件路径
#FILE_BACKUP_USER_KEY_PATH
## 服务器执行脚本路径
#FILE_BACKUP_REMOTE_SHELL_PATH
## 服务器地址
#FILE_BACKUP_HOST_ADDR
## 服务器端口 默认22
#FILE_BACKUP_HOST_PORT

## 备份目录信息,优先级最高 "BACKUP_SOURCE_DIR|BACKUP_TARGET_DIR|REMOTE_SHELL_PATH|USER_NAME|USER_KEY_PATH|HOST_ADDR|HOST_PORT;"
#FILE_BACKUP_CONFIGS


function sendMessage() {
    python3 send.py "执行备份结束" "$1"
}

function file_backup() {
  local USER_NAME="$1"
  local USER_KEY_PATH="$2"
  local HOST_ADDR="$3"
  local HOST_ADDR_PORT="$4"
  local REMOTE_SHELL_PATH="$5"
  local BACKUP_SOURCE_DIR="$6"
  local BACKUP_TARGET_DIR="$7"

  ## 暂时无效
  ZIP_PASSWORD="${FILE_BACKUP_ZIP_PASSWORD}"
  MAX_DAYS=3

  if [ -z $USER_NAME ] || [ -z $HOST_ADDR ] || [ -z ${REMOTE_SHELL_PATH} ] || [ -z ${BACKUP_SOURCE_DIR} ] || [ -z ${BACKUP_TARGET_DIR} ]; then
    local result="各参数均不能为空，用户名=[${USER_NAME}], 服务器地址=[${HOST_ADDR}], 服务器脚本=[${REMOTE_SHELL_PATH}], 备份源目录=[${BACKUP_SOURCE_DIR}], 备份目标目录=[${BACKUP_TARGET_DIR}]"
    sendMessage "${result}"
    return 1;
  fi
  echo "`date +'%Y-%m-%d %H:%M:%S'` USER_NAME=[${USER_NAME}],USER_KEY_PATH=[${USER_KEY_PATH}],HOST_ADDR=[${HOST_ADDR}],HOST_ADDR_PORT=[${HOST_ADDR_PORT}],REMOTE_SHELL_PATH=[${REMOTE_SHELL_PATH}],BACKUP_SOURCE_DIR=[${BACKUP_SOURCE_DIR}],BACKUP_TARGET_DIR=[${BACKUP_TARGET_DIR}]"

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
    echo "ssh ${USER_NAME}@${HOST_ADDR} ${auth_option} ${REMOTE_SHELL_PATH} -s ${BACKUP_SOURCE_DIR} -t ${BACKUP_TARGET_DIR} ${zip_password_option} -l ${MAX_DAYS}"
  fi

  result=$(ssh ${USER_NAME}@${HOST_ADDR} ${auth_option} ${REMOTE_SHELL_PATH} -s ${BACKUP_SOURCE_DIR} -t ${BACKUP_TARGET_DIR} ${zip_password_option} -l ${MAX_DAYS} 2>&1)
  sendMessage "${result}"

#  ssh ${USER_NAME}@${HOST_ADDR} ${auth_option} ${REMOTE_SHELL_PATH} -d ${BACKUP_SOURCE_DIR} -f ${BACKUP_TARGET_DIR} ${zip_password_option} -l ${MAX_DAYS}  > output.log 2>&1
#  python3 send.py "执行备份完成" "${result}"
}

function batch_file_backup() {
  local user_name="${FILE_BACKUP_USER_NAME}"
  local user_key_path="${FILE_BACKUP_USER_KEY_PATH}"
  local host_addr="${FILE_BACKUP_HOST_ADDR}"
  local host_port=${FILE_BACKUP_HOST_PORT}

  local remote_shell_path="${FILE_BACKUP_REMOTE_SHELL_PATH}"
  local backup_source_dir=''
  local backup_target_dir=''

  local BACKUP_CONFIGS="${FILE_BACKUP_CONFIGS}"
  IFS=';' read -ra batch_backup_configs <<< "$BACKUP_CONFIGS"
  for config in ${batch_backup_configs[@]} ; do
    echo -e "\n\n\n本次执行信息: ${config}"
    ((count++))

    ## 变量计算
    IFS='|' read -ra one_vars <<< "${config}"
    if [ -n "${one_vars[0]}" ]; then
        backup_source_dir="${one_vars[0]}"
    fi
    if [ -n "${one_vars[1]}" ]; then
        backup_target_dir="${one_vars[1]}"
    fi
    if [ -n "${one_vars[2]}" ]; then
        remote_shell_path="${one_vars[2]}"
    fi
    if [ -n "${one_vars[3]}" ]; then
        user_name="${one_vars[3]}"
    fi
    if [ -n "${one_vars[4]}" ]; then
        user_key_path="${one_vars[4]}"
    fi
    if [ -n "${one_vars[5]}" ]; then
        host_addr="${one_vars[5]}"
    fi
    if [ -n "${one_vars[6]}" ]; then
        host_port="${one_vars[6]}"
    fi

    ## 默认值赋值
    if [ -z "${HOST_PORT}" ]; then
        HOST_PORT=22
    fi

    file_backup "${user_name}" "${user_key_path}" "${host_addr}" "${host_port}" "${remote_shell_path}" "${backup_source_dir}" "${backup_target_dir}"
  done
}

log_level=1 #DEBUG=1/INFO=2
batch_file_backup