#!/bin/bash

#E necessario que seja configurado o plugin linux ou windows dentro da instancia, base em: http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/mon-scripts.html
#Its necessaty you make a windows or linux scipts on your system operations, based in : http://docs.aws.amazon.com/AmazonCloudWatch/latest/DeveloperGuide/mon-scripts.html

#Voce deve chamar este script passando como parametro os valores para warning e para critical, exemplo: analisa_aws.sh <valor para warning> <valor para critical> <Caminho do arquivo de autenticacao da API> <ID da instancia> <Parametro que deseja monitorar> <namesace (usar System/Linux ou AWS/EC2) >
#You need invite this script and passed the parameters for warning or critical, example: analisa_aws.sh <value to warning> <value to critical> <path to autentication API file> <instance ID> <Parameter to you monitoring> <namespace ( use System/Linux ou AWS/EC2 ) >

nivel_warning=$1
nivel_critical=$2
arquivo_config=$3
id_instancia=$4
parametro=$5
namespace=$6

data_atual=`date -I`
horario_inicial=`date -d "-5 minutes" | awk {'print $4'}`
horario_final=`date | awk {'print $4'}`

valor=`mon-get-stats $parametro --statistics "Average" --namespace "$namespace" --aws-credential-file $arquivo_config --dimensions InstanceId=$id_instancia --period 60 --start-time "$data_atual"T"$horario_inicial".000Z --end-time "$data_atual"T"$horario_final".000Z | awk {'print $3'}`
valor_inteiro=$(echo ${valor} | awk '{print int($0) }')

if [ $valor_inteiro -ge $nivel_warning ]; then echo "Warning - $valor %" && exit 1; fi
if [ $valor_inteiro -ge $nivel_critical ]; then echo "Critical - $valor %" && exit 1; fi
if [ $valor_inteiro -eq 0 ]; then echo "Critical - Esta vindo sem resultado" && exit 1; fi

echo "OK - $valor %"
