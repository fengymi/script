#!/bin/bash
#BAK_DIR=""
#BAK_FILE_DIR=""
#PASSWORD=""
## 文件保持多久删除
#FILE_KEEP_DAYS=0

while getopts "d:f:p:l:" OPTION
    do
        case $OPTION in
        'd')
            BAK_DIR=$OPTARG
             ;;
        'f')
            BAK_FILE_DIR=$OPTARG
            ;;
        'p')
            PASSWORD=$OPTARG
             ;;
        'l')
            # 文件保持多久删除
            FILE_KEEP_DAYS=$OPTARG
            ;;
        \?)
            echo "-d=待备份目录; \n-f=备份后目录; \n-p=压缩密码; \n-l=n天前删除"
            exit 1
            ;;
        esac
    done

function backup_files() {
  local backup_dir=${BAK_DIR}
  local backup_file=${BAK_FILE_DIR}
  local zip_password=${PASSWORD}

  if [ -z $backup_dir ] || [ -z $backup_file ]; then
    echo "备份文件夹=[${backup_dir}]和备份文件=[${backup_file}]均不能为空"
    exit 2;
  fi

  if [ ! -e $backup_dir ]; then
      echo "待备份文件目录[$backup_dir]不存在，忽略"
      exit 2;
  fi

#  创建备份目录
  if [ ! -e "${backup_file}" ]; then
    echo "目录[$backup_file]不存在，进行创建"
    mkdir -p "$backup_file"
  fi

#  保证以/结尾
  local last_char="${backup_file: -1}"
  if [ $last_char != "/" ]; then
      backup_file="${backup_file}/"
  fi

  local directory=$(dirname "${backup_dir}")
  local filename=$(basename "${backup_dir}")
  local current_date=$(date +%Y-%m-%d)
  backup_file="${backup_file}${filename}-${current_date}.zip"

  local password_option=""
  if [ -n "$zip_password" ]; then
    password_option=" -e -P ${zip_password}"
  fi

  echo "backup_file=$backup_file, filename=$backup_dir"

  local zip_shell="zip -dc -q ${password_option} -r $backup_file $filename" # >> /var/log/file_bakup.log
  echo "${zip_shell}"
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

  local file_count=$(zipinfo -l $backup_file | wc -l)
  echo "备份完成
  目录:${backup_dir};
  文件:${backup_file};
  备份文件数量:${file_count}"
}

function remove_history_files() {
  local backup_file_dir=${BAK_FILE_DIR}
  local remove_file_before_day=${FILE_KEEP_DAYS}

  if [ -z "${remove_file_before_day}" ] || [ ${remove_file_before_day} -le 0 ]; then
    echo "文件保存天数=${remove_file_before_day}天没有限制,不进行文件删除"
    exit 0;
  fi

  local files=$(find ${backup_file_dir} -type f -ctime +${remove_file_before_day})
  if [ -z "${files}" ]; then
      echo "没有需要删除的文件，忽略本次删除"
      exit 0;
  fi
  
  echo "需要删除的文件: ${files}"
#  rm -rf $files
##  find ${backup_file_dir} -ctime -3 -exec echo {} \;
  echo "成功删除的文件: ${files}"
}

backup_files && remove_history_files
