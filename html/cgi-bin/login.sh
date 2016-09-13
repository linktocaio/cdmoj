#!/bin/bash
#This file is part of CD-MOJ.
#
#CD-MOJ is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#Foobar is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

source common.sh

POST="$(cat )"
AGORA="$(date +%s)"
CAMINHO="$PATH_INFO"
CONTEST="$(cut -d'/' -f2 <<< "$CAMINHO")"
CONTEST="${CONTEST// }"

if [[ "x$POST" != "x" ]]; then
  LOGIN="$(grep -A2 'name="login"' <<< "$POST" |tail -n1|tr -d '\n'|tr -d '\r')"
  SENHA="$(grep -A2 'name="senha"' <<< "$POST" |tail -n1|tr -d '\n'|tr -d '\r')"
  #escapar coisa perigosa
  LOGIN="$(echo $LOGIN | sed -e 's/\([[\/*]\|\]\)/\\&/g')"
  SENHA="$(echo $SENHA | sed -e 's/\([[\/.*]\|\]\)/\\&/g')"
  if ! grep -q "^$LOGIN:$SENHA:" $CONTESTSDIR/$CONTEST/passwd; then
    cabecalho-html
    cat << EOF
  <script type="text/javascript">
    window.alert("Senha Incorreta");
    top.location.href = "$BASEURL/cgi-bin/contest.sh/$CONTEST"
  </script>
EOF
    exit 0
  fi
  NOVAHASH=$(echo "$(date +%s)$RANDOM$LOGIN" |md5sum |awk '{print $1}')
  printf "$NOVAHASH" > "$CACHEDIR/$LOGIN-$CONTEST"

  #avisa do login
  touch  $SUBMISSIONDIR/$CONTEST:$AGORA:$RAND:$LOGIN:login:dummy

  #enviar cookie
  ((ESPIRA= AGORA + 36000))
  printf "Set-Cookie: login=$LOGIN; Path=/;  expires=$(date --date=@$ESPIRA)\n"
  printf "Set-Cookie: hash=$NOVAHASH; Path=/; expires=$(date --date=@$ESPIRA)\n"
  printf "Content-type: text/html\n\n"
  cat << EOF
  <script type="text/javascript">
    top.location.href = "$BASEURL/cgi-bin/contest.sh/$CONTEST"
  </script>

EOF
  exit 0

elif verifica-login $CONTEST |grep -q Nao; then
  tela-login $CONTEST
fi

#printf "Location: /~moj/cgi-bin/contest.sh/$CONTEST\n\n"
  printf "Content-type: text/html\n\n"
  cat << EOF
  <script type="text/javascript">
    top.location.href = "$BASEURL/cgi-bin/contest.sh/$CONTEST"
  </script>

EOF
exit 0
