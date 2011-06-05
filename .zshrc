source ~/.profile

setopt printeightbit

hash -d scm=$SVNROOT
hash -d plt=$PLTHOME
hash -d ws=~plt/collects/web-server
hash -d drdr=~plt/collects/meta/drdr
hash -d work=$PROJS
hash -d papers=~work/papers
hash -d planet=~scm/github.jeapostrophe.planet
hash -d github=~scm/github.jeapostrophe
hash -d gb=~github/get-bonus
hash -d exp=~scm/github.jeapostrophe/exp
hash -d fin=~scm/github.jeapostrophe/home/finance
hash -d fspec=~scm/svn.smc-lab/students/MS/morse-everett/fspec/trunk
hash -d uber-lazy=~scm/svn.smc-lab/students/PhD/rungta-neha/papers/uber-lazy/trunk
hash -d courses=~work/courses
hash -d 630=~courses/2011/winter/630
hash -d j=~github/home/journal

export PATH=~exp/bin:~work/papers/etc/bin:$PATH

setopt autopushd pushdminus pushdsilent pushdtohome

autoload -U zmv
autoload -U compinit
compinit 

export PS1="%S%~%s
%# "
TPS1="%~ %# "
RECENTFILES=8

# Interaction with Emacs:
function set-eterm-dir {
    echo -e "\033AnSiTc" "$(pwd)"
}

        # Track directory, username, and cwd for remote logons.
if [ "$TERM" = "eterm-color" ]; then
    precmd () { set-eterm-dir }
else
    precmd () {print -Pn "\e]0;$TPS1\a"}
    preexec () {print -Pn "\e]0;$TPS1 $2\a"}
fi

ZDIR=~/.zdir

# Read in ZDIR
write_zdir () {
    pwd >! $ZDIR
}

# Read in ZDIR
read_zdir () {
    pushd "$(cat $ZDIR)"
}

chpwd () {
    # Save what directory we are in for the future
    write_zdir
    # Show recently modified files
    ls -t | head -$RECENTFILES | tr '\n' '\0' | xargs -0 ls -d
}

if [ $(pwd) = ${HOME} ] ; then
    read_zdir
fi

# Completions
compctl -g '*(/)' rmdir dircmp
compctl -g '*(-/)' cd chdir dirs pushd
#compctl -z -P '%' bg
#compctl -j -P '%' fg jobs disown
#compctl -j -P '%' + -s '`ps -x | tail +2 | cut -c1-5`' wait

# Caching
#zstyle ':completion:*' use-cache on
#zstyle ':completion:*' cache-path ~/.zsh/cache

# Adding known hosts
#local _myhosts
#if [[ -f "$HOME/.ssh/known_hosts" ]]; then
#  _myhosts=( ${${${${(f)"$(<$HOME/.ssh/known_hosts)"}:#[0-9]*}%%\ *}%%,*} )
#  zstyle ':completion:*' hosts $_myhosts
#fi

# Ignore what's in the line
#zstyle ':completion:*:(rm|kill|diff):*' ignore-line yes
