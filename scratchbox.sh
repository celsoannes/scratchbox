#!/bin/bash
# CRIA JAIL BASICO CHROOT

# BINARIOS DISPONIVEIS NO AMBIENTE
BIN=( bash tr cat clear grep less ls cp mkdir mv rm rmdir tail find head cut tar nano vi vim dircolors tar gzip whereis sh sed touch gunzip whoami )


# PASTAS BASICAS DO SISTEMA
DIRECTORY=( bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var )

# CAMINHO ONDE SERA CRIADA A JAIL
JAIL=/home/jogo


#---------- INICIO ----------#
# CRIA PASTA JAIL
rm -rf $JAIL
mkdir -p -v $JAIL

#---------- REQUISITOS OBRIGATORIOS ----------#
# CRIA PASTAS DO SISTEMA
D=0
while [ "$D" -lt ${#DIRECTORY[@]} ]
do
    mkdir -p -v $JAIL/${DIRECTORY[$D]}
    (( D++ ))
done

mknod -m 666 $JAIL/dev/null c 1 3
mknod -m 666 $JAIL/dev/tty c 5 0
mknod -m 666 $JAIL/dev/zero c 1 5
mknod -m 666 $JAIL/dev/random c 1 8

# CRIA LINKS SIMPOLICOS
ln -s -v $JAIL/usr/sbin $JAIL/sbin
ln -s -v $JAIL/usr/bin $JAIL/bin


chmod 777 $JAIL/tmp



# GRAVA CAMINHO COMPLETO DOS BINARIOS
B=0
while [ "$B" -lt ${#BIN[@]} ]
do
    # CAMINHO DO BINARIO
    BINPATH=`type -a ${BIN[$B]} | awk '{print $3}'`

    # ADICIONA CAMINHO DO BINARIO
    WHEREIS+=("$BINPATH")

    # ADICIONA CAMINHO DOS MANUAIS
    #WHEREIS+=(`whereis -m ${BIN[$B]} | cut -d ':' -f2`)

    # ADICIONA CAMINHO COMPLETO DAS BIBLIOTECAS USADAS PELOS BINARIOS
    # NAO ESTA CONSIDERANDO AS BIBLIOTECAS /lib64
    WHEREIS+=(`ldd $BINPATH | awk 'BEGIN{ORS=","}$1~/^\//{print $1}$3~/^\//{print $3}' | sed 's/,$/\n/' | sed 's/,/ /g'`)

    # ADICIONA CAMINHO COMPLETO DAS BIBLIOTECAS 64 USADAS PELOS BINARIOS
    WHEREIS+=(`ldd $BINPATH | awk '{ print $1 }' | grep '/lib64'`)

    # VERIFICA COM strace QUAIS ARQUIVOS CADA BIN NECESSITA
    echo "strace ${BIN[$B]}"
    WHEREIS+=(`timeout 5s strace ${BIN[$B]} 2>&1 | grep 'open("\|stat("' | grep -v '".."\|openat\|No such file or directory\|"."\|open("/dev' | cut -d '"' -f2 | tr "\n" " "`)


    (( B++ ))
done


# REMOVE DUPLICADOS
WHEREIS=(`echo ${WHEREIS[@]} | tr " " "\n" | sort | uniq | tr "\n" " "`)


# VERIFICA TODOS OS CAMINHOS QUE PRECISAM SER CRIADOS
I=0
while [ "$I" -lt ${#WHEREIS[@]} ]
do
    FILEPATH+=("${WHEREIS[$I]%/*}")
    (( I++ ))
done

# REMOVE TODOS OS CAMINHOS DUPLICADOS E CRIA OS CAMINHOS NECESSARIOS
echo ${FILEPATH[@]} | sed 's/ /\n/g' | sort | uniq | xargs -I {} mkdir -p -v $JAIL{}

# COPIA BINARIOS MANUAIS E BIBLIOTECAS PARA SEUS DESTINOS NA JAIL
echo ${WHEREIS[@]} | sed 's/ /\n/g' | xargs -I {} cp -p -v {} $JAIL{}


#---------- REQUISITOS OBRIGATORIOS ----------#
# TERMINFO
cp -a -v /usr/share/terminfo/ $JAIL/usr/share/
chmod 555 $JAIL/usr/share/terminfo
cp -a -v /lib/terminfo $JAIL/lib

# PREPARA DIRETORIO root
mkdir -p -v $JAIL/root
cat /root/.bashrc > $JAIL/root/.bashrc

# ADICIONA USUARIO root ao sistema
cat /etc/passwd | grep 'root:' > $JAIL/etc/passwd
cat /etc/group | grep 'root' > $JAIL/etc/group


# ADICIONANDO SUPORTE AOS MANUAIS
#cp -v /etc/manpath.config $JAIL/etc
#cp -v /etc/locale.gen $JAIL/etc
#cp -v /etc/default/locale $JAIL/etc/default

#cp -a /usr/bin/locale /home/jogo/usr/bin/locale
#cp -a /usr/lib/locale /home/jogo/usr/lib/locale
#cp -a /etc/locale.gen /home/jogo/etc/locale.gen
#cp -a /etc/locale.alias /home/jogo/etc/locale.alias
#cp -a /usr/share/locale /home/jogo/usr/share/locale
#cp -a /usr/share/man/man7/locale.7.gz /home/jogo/usr/share/man/man7/locale.7.gz
#cp -a /usr/share/man/man5/locale.5.gz /home/jogo/usr/share/man/man5/locale.5.gz
#cp -a /usr/share/man/man1/locale.1.gz /home/jogo/usr/share/man/man1/locale.1.gz

#WHEREIS+=( /etc/manpath.config /etc/locale.gen /etc/default/locale /usr/bin/locale /usr/lib/locale /etc/locale.gen /etc/locale.alias /usr/share/locale /usr/share/man/man7/locale.7.gz /usr/share/man/man5/locale.5.gz /usr/share/man/man1/locale.1.gz  )


##---------- VIM ----------#
# CORRIGINDO SETAS
echo 'set term=builtin_ansi' > $JAIL/root/.vimrc
# CORRIGE PROBLEMA COM TECLAS HOME END DEL
echo 'set term=xterm' >> $JAIL/root/.vimrc
# CORRIGE BACKSPACE
echo 'set nocompatible' >> $JAIL/root/.vimrc
echo 'set backspace=2' >> $JAIL/root/.vimrc
# SYNTAX HIGHLIGHTER
cp -a -v /etc/vim/ $JAIL/etc/
cp -a -v /usr/share/vim $JAIL/usr/share
#
#---------- NANO ----------#
# SYNTAX HIGHLIGHTER
cp -a -v /usr/share/nano/ $JAIL/usr/share/
find /usr/share/nano/ -name "*.nanorc" | xargs printf "include %s\n" >> $JAIL/root/.nanorc
