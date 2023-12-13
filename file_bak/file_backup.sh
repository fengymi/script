#!/bin/bash

while getopts "s:t:p:l:" OPTION
    do
        case $OPTION in
        's')
            BAK_SOURCE_DIR=$OPTARG
             ;;
        't')
            BAK_TARGET_DIR=$OPTARG
            ;;
        'p')
            PASSWORD=$OPTARG
             ;;
        'l')
            # 文件保持多久删除
            FILE_KEEP_DAYS=$OPTARG
            ;;
        \?)
            echo -e "-s=待备份目录; \n-t=备份后目录; \n-p=压缩密码; \n-l=n天前删除"
            exit 1
            ;;
        esac
    done


LOG_PATH='/var/log/file_backup.log'
MAX_FAIL_COUNT=0 # 允许失败文件数(失败还记录备份成功)
LOG_LEVEL=2 # 1-debug, 2-info

function backup_files() {
  log_print "backup_files: ${BAK_SOURCE_DIR} -> ${BAK_TARGET_DIR}" "true"
  local backup_source_dir=${BAK_SOURCE_DIR}
  local backup_target_dir=${BAK_TARGET_DIR}

  if [ -z $backup_source_dir ] || [ -z $backup_target_dir ]; then
    log_print "备份文件夹=[${backup_source_dir}]和备份文件=[${backup_target_dir}]均不能为空" "true"
    exit 2;
  fi

  if [ ! -e $backup_source_dir ]; then
      log_print "待备份文件目录[$backup_source_dir]不存在，忽略" "true"
      exit 2;
  fi

  #  创建备份目录
  if [ ! -e "${backup_target_dir}" ]; then
    log_print "目录[$backup_target_dir]不存在，进行创建"
    mkdir -p "$backup_target_dir"
  fi

  #  保证以/结尾
  backup_target_dir=`fulfill_dir_path "${backup_target_dir}"`
  backup_source_dir=`fulfill_dir_path "${backup_source_dir}"`
  increment_backup ${backup_source_dir} ${backup_target_dir}
}

function fulfill_dir_path() {
  local dir_path=$1
  local last_char="${dir_path: -1}"
  if [ $last_char != "/" ]; then
      dir_path="${dir_path}/"
  fi
  echo "${dir_path}"
}

## 增量更新
function increment_backup() {
  local backup_source_dir=$1
  local backup_target_dir=$2

  local md5_key=`echo -n "${backup_source_dir}_${backup_target_dir}"|md5sum|cut -d ' ' -f1`
  local last_update_success_time_file_name="${backup_target_dir}last_updated_success_time_${md5_key}.txt"
  local last_update_log_file_name="${backup_target_dir}last_updated_log_${md5_key}.txt"

  local last_updated_success_time=0;
  if [ -f "${last_update_success_time_file_name}" ]; then
    last_updated_success_time=`cat ${last_update_success_time_file_name}`
  fi

  local last_updated_success_time_format=`date -d @"$last_updated_success_time" "+%Y-%m-%d %H:%M:%S"`
  log_print "上次更新时间: ${last_updated_success_time} -- ${last_updated_success_time_format}"
  echo "`date +'%Y-%m-%d %H:%M:%S'` 上次更新成功时间: ${last_updated_success_time} -- ${last_updated_success_time_format}" > ${last_update_log_file_name}
  echo "`date +'%Y-%m-%d %H:%M:%S'` 开始备份: `date +'%Y-%m-%d %H:%M:%S'`" >> ${last_update_log_file_name}
  ## 执行增量更新
#  local file_last_update_time=$(date -d @${last_updated_success_time} +'%Y-%m-%d %H:%M:%S')
#  local find_files_cmd="find \"${backup_source_dir}\" -type f -newermt \"${file_last_update_time}\""
#  local files=`${find_files_cmd}`;
  local files=`find "${backup_source_dir}" -type f -newermt "$(date -d @${last_updated_success_time} +'%Y-%m-%d %H:%M:%S')"`;

  ## 记录备份文件数
  local count=`find "${backup_source_dir}" -type f -newermt "$(date -d @${last_updated_success_time} +'%Y-%m-%d %H:%M:%S')" | wc -l`
  log_print "待备份文件数: ${count}"
  local success_count=0
  local fail_count=0
  local ignore_count=0

  if [ $count -le 0 ]; then
      log_print "不存在增量文件,忽略" "true"
      exit 0
  fi

  local current_update_time=$(date +%s)

  local oldIFS=$IFS
  IFS=$'\n'
  for file in ${files} ; do
    local base_filename=$(basename "$file")
    local filename=${file//$backup_source_dir/}
    local temp_dir=${filename//$base_filename/}

    if [ ${LOG_LEVEL} -le 1 ]; then
      echo "file=${file}, base_filename=${base_filename}, filename=${filename}, temp_dir=${temp_dir}"
    fi

    ## 创建目标相同目录
    local target_dir_path="${backup_target_dir}${temp_dir}"
    if [ ! -d "$target_dir_path" ]; then
        mkdir -p "${target_dir_path}"
    fi

    local target_file_path="${target_dir_path}/${base_filename}"
    diff_files ${file} ${target_file_path}
    local diff_code=$?
    if [ ${diff_code} -ne 0 ]; then
#      log_print "文件已存在，忽略: ${file}"
      ((ignore_count++))
      echo -ne "`date +'%Y-%m-%d %H:%M:%S'` 执行进度[成功数/失败数/忽略数/总数]: ${success_count}/${fail_count}/${ignore_count}/${count}\r" >> "${LOG_PATH}"
      continue
    fi

    if [ ${LOG_LEVEL} -le 1 ]; then
      echo "待备份文件: ${file}, 原文件名: ${filename}, 目标文件: ${target_dir_path}"
      echo "cp -rp ${file} ${target_dir_path}"
    fi
    cp -rp "${file}" "${target_dir_path}"
    local cp_code=$?
    if [ $cp_code -eq 0 ]; then
      ((success_count++))
    else
      log_print "${file} 备份失败" "true"
      ((fail_count++))
    fi

    echo -ne "`date +'%Y-%m-%d %H:%M:%S'` 执行进度[成功数/失败数/忽略数/总数]: ${success_count}/${fail_count}/${ignore_count}/${count}\r" >> "${LOG_PATH}"
  done
  echo -ne "`date +'%Y-%m-%d %H:%M:%S'` 执行进度[成功数/失败数/忽略数/总数]: ${success_count}/${fail_count}/${ignore_count}/${count}\r\n" >> "${LOG_PATH}"
  IFS=$oldIFS

  log_print "增量备份执行完成count=${count}, success_count=${success_count}, fail_count=${fail_count}, ignore_count=${ignore_count}" "true"
  if [ $fail_count -gt $MAX_FAIL_COUNT ]; then
      log_print "允许最大失败数<本次失败数: ${MAX_FAIL_COUNT}<${fail_count}, 不更新最终结果,允许下次重新更新目录" "true"
      exit 3;
  fi

  ## 记录更新成功
  echo "${current_update_time}" > ${last_update_success_time_file_name}
  echo "`date +'%Y-%m-%d %H:%M:%S'` 备份完成: count=${count}, success_count=${success_count}, fail_count=${fail_count}, ignore_count=${ignore_count}" >> ${last_update_log_file_name}
  echo "`date +'%Y-%m-%d %H:%M:%S'` 本次更新成功时间戳: ${current_update_time}" >> ${last_update_log_file_name}
}

function diff_files() {
  local source_file=$1
  local destination_file=$2

  if [ ! -f $destination_file ]; then
      return 0
  fi

  # 检查目标文件是否存在且与源文件相同
  if [ -f "$destination_file" ] && cmp -s "$source_file" "$destination_file"; then
      return 1
  else
      return 0
  fi
}


## 全量备份
function full_backup() {
  local backup_source_dir=${BAK_SOURCE_DIR}
  local backup_target_dir=${BAK_TARGET_DIR}
  local zip_password=${PASSWORD}

  if [ -z $backup_source_dir ] || [ -z $backup_target_dir ]; then
    log_print "备份文件夹=[${backup_source_dir}]和备份文件=[${backup_target_dir}]均不能为空" "true"
    exit 2;
  fi

  if [ ! -e $backup_source_dir ]; then
      log_print "待备份文件目录[$backup_source_dir]不存在，忽略" "true"
      exit 2;
  fi

#  创建备份目录
  if [ ! -e "${backup_target_dir}" ]; then
    log_print "目录[$backup_target_dir]不存在，进行创建"
    mkdir -p "$backup_target_dir"
  fi

#  保证以/结尾
  local last_char="${backup_target_dir: -1}"
  if [ $last_char != "/" ]; then
      backup_target_dir="${backup_target_dir}/"
  fi

  local directory=$(dirname "${backup_source_dir}")
  local filename=$(basename "${backup_source_dir}")
  local current_date=$(date +%Y-%m-%d)
  backup_target_dir="${backup_target_dir}${filename}-${current_date}.zip"

  local password_option=""
  if [ -n "$zip_password" ]; then
    password_option=" -e -P ${zip_password}"
  fi

  log_print "backup_target_dir=$backup_target_dir, filename=$backup_source_dir"

  local zip_shell="zip -dc -q ${password_option} -r $backup_target_dir $filename >>${LOG_PATH}"
  log_print "${zip_shell}"
  if [ -n $directory ]; then
    cd ${directory} && `${zip_shell}`
  else
    `zip_shell`
  fi
  
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "执行备份失败，错误码=$exit_code"
    exit $exit_code
  fi

  local file_count=$(zipinfo -l $backup_target_dir | wc -l)
  log_print "备份完成
  目录:${backup_source_dir};
  文件:${backup_target_dir};
  备份文件数量:${file_count}" "true"
}

function remove_history_files() {
  local backup_target_dir_dir=${BAK_TARGET_DIR}
  local remove_file_before_day=${FILE_KEEP_DAYS}

  if [ -z "${remove_file_before_day}" ] || [ ${remove_file_before_day} -le 0 ]; then
    echo "文件保存天数=${remove_file_before_day}天没有限制,不进行文件删除"
    exit 0;
  fi

  local files=$(find ${backup_target_dir_dir} -type f -ctime +${remove_file_before_day})
  if [ -z "${files}" ]; then
      log_print "没有需要删除的文件，忽略本次删除"
      exit 0;
  fi
  
  log_print "需要删除的文件: ${files}"
  rm -rf $files
  log_print "成功删除的文件: ${files}" "true"
}

function log_print() {
  if [ -z "$1" ]; then
      exit 1;
  fi

  echo "`date +'%Y-%m-%d %H:%M:%S'` $1" >> /var/log/file_backup.log

  if [ "$2" == "true" ]; then
    echo "`date +'%Y-%m-%d %H:%M:%S'` $1"
  fi
}

backup_files #&& remove_history_files
