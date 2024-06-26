#!/bin/bash
#This file is part of CD-MOJ.
#
#CD-MOJ is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#CD-MOJ is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with CD-MOJ.  If not, see <http://www.gnu.org/licenses/>.

source common.sh

CAMINHO="$PATH_INFO"

if verifica-login treino |grep -q Nao; then
  tela-login treino/conquistas.usuario
fi
LOGIN=$(pega-login)


IS_ADMIN=""
if [[ "$LOGIN" =~ ".admin" ]] ||  [[ "$LOGIN" =~ ".mon" ]]; then
  IS_ADMIN="
    <script type="text/javascript">
      document.addEventListener('DOMContentLoaded', function() {
        const isAdminContainer = document.createElement('div');
        isAdminContainer.innerHTML = \`
          <form enctype="multipart/form-data" action="$BASEURL/cgi-bin/conquistas.sh" method="post">
              <label>Escolha um usuario:</label>
              <input name="user" type="text">
              <input type="submit" value="personificar">
          </form>
        \`;
        const titulo = document.querySelector('h1');
        titulo.insertAdjacentElement('afterend', isAdminContainer);
      });
    </script>
  "
  POST="$(cat)"
  if [[ "x$POST" != "x" ]]; then
    LOGIN="$(grep -A2 'name="user"' <<<"$POST" | tail -n1 | tr -d '\n' | tr -d '\r')"

    if [ ! -d "$CONTESTSDIR/treino/controle/$LOGIN.d" ]; then
      tela-erro
      exit 0
    fi
  fi
fi


USER_CONQS="$CONTESTSDIR/treino/var/conquistas/$LOGIN"

# Verifica se o arquivo de buffer ja existe. life span = 5min
if [[ -f "$USER_CONQS" ]]; then
  CONQT=$(stat -c %Y "$USER_CONQS")
  if (( EPOCHSECONDS - CONQT < 300 )); then
    (
      flock -x 42
      cat "$USER_CONQS"
      echo $IS_ADMIN
      exit 0
    ) 42<"$USER_CONQS"

      exit 0
  fi
fi

# flock para evitar concorrencia. File descriptor = 42;
(
flock -x 42
exec > >(tee "$USER_CONQS")

# TOTAL KD -----------------------------------------------
KD=""
if [ -d "$CONTESTSDIR/treino/controle/$LOGIN.d" ]; then
  ACERTOU=0
  SUBMISSOES=0

  for registro in "$CONTESTSDIR/treino/controle/$LOGIN.d"/*; do
    questao="$(basename "$registro")"
    if [ -d "$CONTESTSDIR/treino/var/questoes/$questao" ]; then
      source $registro
      ACERTOU=$(expr $ACERTOU + $JAACERTOU)
      SUBMISSOES=$(expr $SUBMISSOES + $TENTATIVAS)
    fi
  done

  KD="
    <div style='border: 1px solid #e0e0e0; padding: 15px; font-size: 18px;'>
      <span><b>Usuario: </b> $LOGIN </span>
      <div style='display: flex; justify-content: space-between;  padding-top: 15px'>
      <span><b>Acertos: </b>$ACERTOU </span> |
      <span><b>Tentativas: </b>$SUBMISSOES </span> |
      <span><b>K/D: </b>$(printf "%.2f\n" $(echo "scale=3; ($ACERTOU / $SUBMISSOES) + 0.005" | bc))</span>
      </div>
    </div>
  "
fi

QUESTOES=""
if [ -d "$CONTESTSDIR/treino/controle/$LOGIN.d" ]; then

# QUESTOES -----------------------------------------------
    for login_data in "$CONTESTSDIR/treino/controle/$LOGIN.d"/*; do
      questao="$(basename "$login_data")"

      if [ -d "$CONTESTSDIR/treino/var/questoes/$questao" ]; then
        source $login_data

        QUESTOES+=$( < $CONTESTSDIR/treino/var/questoes/$questao/li)

        # Removendo </li> para adicionar div abaixo
        QUESTOES="${QUESTOES::-5}"
        QUESTOES+="    
            <div class="titcontest" style='border-bottom: 1px dotted #c1c1c1; display: flex; justify-content: space-between; padding-bottom: 5px'>
              <span><b>Acertos: </b> $JAACERTOU </span> |
              <span><b>Tentativas: </b>$TENTATIVAS </span> |
              <span><b>K/D: </b>$(printf "%.2f\n" $(echo "scale=3; ($JAACERTOU / $TENTATIVAS) + 0.005" | bc))</span>
            </div>
          </li>
        "
      fi
    done

# TAGS -----------------------------------------------
  declare -A tag_jaacertou_totals
  declare -A tag_tentativas_totals
  declare -A tag_questions

  for login_data in "$CONTESTSDIR/treino/controle/$LOGIN.d/"*; do
    questao=$(basename "$login_data")

    if [ -d "$CONTESTSDIR/treino/var/questoes/$questao" ]; then
      source $login_data
      total_jaacertou="$JAACERTOU"
      total_tentativas="$TENTATIVAS"
      
      tags_file="$CONTESTSDIR/treino/var/questoes/$questao/tags"
      
      if [ -f "$tags_file" ]; then
        while IFS= read -r tag; do
          tag_jaacertou_totals["$tag"]=$((tag_jaacertou_totals["$tag"] + total_jaacertou))
          tag_tentativas_totals["$tag"]=$((tag_tentativas_totals["$tag"] + total_tentativas))
          tag_questions["$tag"]+="$questao "
            
        done < "$tags_file"
      fi
    fi
  done

  TAGS=""
  for tag in "${!tag_jaacertou_totals[@]}"; do
    total_jaacertou="${tag_jaacertou_totals["$tag"]}"
    total_tentativas="${tag_tentativas_totals["$tag"]}"
    questions="${tag_questions["$tag"]}"
      
    TAGS+="
    <li>
      <span class="titcontest"><a href="/cgi-bin/tag.sh/${tag:1}"><b>$tag</b></a></span>

      <div class="inTags"><b>Questoes: </b>
        <div class="contestTags">
    "
    for question in ${questions}; do
      if [ -f "$CONTESTSDIR/treino/enunciados/$question".html ]; then
        TAGS+=$(printf "<a class=\"tagCell\" href=\"/cgi-bin/questao.sh/%s\">%s</a>" ${question//#/%23} ${question#*#})
      else
        TAGS+=$(printf "<a class=\"tagCell\" style=\"color: #888 !important;\">%s</a>"  ${question#*#})
      fi
    done <<< "$questions"

    TAGS+="
        </div>
      </div>

      <div class="titcontest" style='border-bottom: 1px dotted #c1c1c1; display: flex; justify-content: space-between; padding-bottom: 5px'>
        <span><b>Acertos: </b> $total_jaacertou </span> |
        <span><b>Tentativas: </b>$total_tentativas </span> |
        <span><b>K/D: </b>$(printf "%.2f\n" $(echo "scale=3; ($total_jaacertou / $total_tentativas) + 0.005" | bc))</span>
      </div>
    </li>
    "
  done
fi

if [[ -z "$QUESTOES" ]] || [[ -z "$TAGS" ]]; then
  QUESTOES="Oops, parece que voce ainda nao possui conquistas"
  TAGS="$QUESTOES"
fi

cabecalho-html
cat <<EOF
<script type="text/javascript" src="/js/treino.js"></script>
<script type="text/javascript" src="/js/simpletabs_1.3.packed.js"></script>

<style type="text/css" media="screen">
  @import "/css/treino.css";
  @import "/css/conquistas.css";
</style>

<h1>Conquistas do Usuario</h1>

$KD

<div class="simpleTabs">
  <ul class="simpleTabsNavigation">
      <li><a href="#">Questoes</a></li>
      <li><a href="#">Tags</a></li>
  </ul>

  <div class="simpleTabsContent">
    <div class="treino">
      <div class="treinoTabs">
        <!--- Pagination script --->
        <div class="conquistas">
          <ul class="treinoList">
            $QUESTOES
          </ul>
        </div>
      </div>
    </div>
  </div>

  <div class="simpleTabsContent">
    <div class="treino">
      <div class="treinoTabs">
        <!--- Pagination script --->
        <div class="conquistas">
          <ul class="treinoList">
            $TAGS
          </ul>
        </div>
      </div>
    </div>
  </div>
</div>

<div style='border: 1px solid #e0e0e0; padding: 5px;'>
  Ultima atualização: $(date +"%d/%m/%Y %H:%M:%S")
</div>
EOF
cat ../footer.html

) 42>"$USER_CONQS"

echo $IS_ADMIN

exit 0
