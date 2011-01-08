#!/bin/bash

if [ "$1" = "" ]; then
	echo "ex. $0 core or $0 extra"
	exit 1
fi

absdir=/var/abs
makepkg_conf=/etc/makepkg.conf
blacklist=$absdir/blacklist-$1

clean_var() {
	noextract=""
	pkgbase=""
	pkgname=""
	pkgver=""
	pkgrel=""
	_darcstruck=""
	_darcsmod=""
	_cvsroot=""
	_cvsmod=""
	_gitroot=""
	_gitmod=""
	_svntruck=""
	_svnmod=""
	_bzrtruck=""
	_bzrmod=""
	_hgroot=""
	_hgrepo=""
	_hgrev=""
	_hgbranch=""
}

devel_sources() {
	if [[ -n ${_darcstrunk} && -n ${_darcsmod} ]] ; then
		if [ ! -d $srcdir ]; then
			mkdir $srcdir
		fi
		pushd $srcdir
		darcs get --partial --set-scripts-executable $_darcstrunk/$_darcsmod
		popd
	elif [[ -n ${_cvsroot} && -n ${_cvsmod} ]] ; then
		if [ ! -d $srcdir ]; then
			mkdir $srcdir
		fi
		pushd $srcdir
		if [ -d $_cvsmod/CVS ]; then
			cd $_cvsmod
			cvs -z3 update -d
			pushd $srcdir
		else
			cvs -z3 -d $_cvsroot co -D $pkgver -f $_cvsmod
		fi
		popd
	elif [[ -n ${_gitroot} && -n ${_gitname} ]] ; then
		if [ ! -d $srcdir ]; then
			mkdir $srcdir
		fi
		pushd $srcdir
		if [ -d $_gitname/.git ]; then
			cd $_gitname && git pull origin
			pushd $srcdir
		else
			git clone $_gitroot $_gitname
		fi
		popd
	elif [[ -n ${_svntrunk} && -n ${_svnmod} ]] ; then
		if [ ! -d $srcdir ]; then
			mkdir $srcdir
		fi
		pushd $srcdir
		if [ -d $_svnmod/.svn ]; then
			cd $_svnmod && svn up -r $pkgver
			pushd $srcdir
		else
			svn co $_svntrunk --config-dir ./ -r $pkgver $_svnmod
		fi
		popd
	elif [[ -n ${_svnroot} && -n ${_svnmod} ]]; then
		if [ ! -d $srcdir ]; then
			mkdir $srcdir
		fi
		pushd $srcdir
		if [ -d $_svnmod/.svn ]; then
			cd $_svnmod && svn up
			pushd $srcdir
		else
			svn co $_svnroot/$_svnmod --config-dir ./ 
		fi
		popd
	elif [[ -n ${_bzrtrunk} && -n ${_bzrmod} ]] ; then
		if [ ! -d $srcdir ]; then
			mkdir $srcdir
		fi
		pushd $srcdir
		bzr co $_bzrtrunk $_bzrmod
		popd
	elif [[ -n ${_hgroot} && -n ${_hgrepo} ]] ; then
		if [ ! -d $srcdir ]; then
			mkdir $srcdir
		fi
		pushd $srcdir
		if [[ -n ${_hgrev} && -n ${_hgbranch} ]]; then
			if [ -d $_hgrepo ]; then
				cd ${_hgrepo}
				hg pull -b ${_hgbranch} || echo 'hg pull failed'
				hg update -r ${_hgrev}
			else
				hg clone -b ${_hgbranch} -u ${_hgrev} "${_hgroot}${_hgrepo}" ${_hgrepo}
			fi
		else
			if [ -d $_hgrepo ]; then
				cd $_hgrepo
				hg pull -u
				pushd $srcdir
			else
				hg clone $_hgroot $_hgrepo
			fi
		fi
		popd
	fi
}

remove_softlinks() {
	RM_SOFT_TARGZ="$(find $srcdir -maxdepth 1 -type l -name "*.tar.gz")"
	if [ "$RM_SOFT_TARGZ" ]; then
		for i in ${RM_SOFT_TARGZ}; do
			rm -vf $i
		done
	fi
	RM_SOFT_TARXZ="$(find $srcdir -maxdepth 1 -type l -name "*.tar.xz")"
	if [ "$RM_SOFT_TARXZ" ]; then
		for i in ${RM_SOFT_TARXZ}; do
			rm -vf $i
		done
	fi
	RM_SOFT_ZIP="$(find $srcdir -maxdepth 1 -type l -name "*.zip")"
	if [ "$RM_SOFT_ZIP" ]; then
		for i in ${RM_SOFT_ZIP}; do
			rm -vf $i
		done
	fi
	#RM_SOFT_TARLZMA="$(find $srcdir -maxdepth 1 -type l -name "*.tar.lzma")"
	#if [ "$RM_SOFT_TARLZMA" ]; then
	#	for i in ${RM_SOFT_TARLZMA}; do
	#		rm -vf $i
	#	done
	#fi
	RM_SOFT_TARBZ2="$(find $srcdir -maxdepth 1 -type l -name "*.tar.bz2")"
	if [ "$RM_SOFT_TARBZ2" ]; then
		for i in ${RM_SOFT_TARBZ2}; do
			rm -vf $i
		done
	fi
	RM_SOFT_GZ="$(find $srcdir -maxdepth 1 -type l -name "*.gz")"
	if [ "$RM_SOFT_GZ" ]; then
		for i in ${RM_SOFT_GZ}; do
			rm -vf $i
		done
	fi
	RM_SOFT_BZ2="$(find $srcdir -maxdepth 1 -type l -name "*.bz2")"
	if [ "$RM_SOFT_BZ2" ]; then
		for i in ${RM_SOFT_BZ2}; do
			rm -vf $i
		done
	fi
	RM_SOFT_TGZ="$(find $srcdir -maxdepth 1 -type l -name "*.tgz")"
	if [ "$RM_SOFT_TGZ" ]; then
		for i in ${RM_SOFT_TGZ}; do
			rm -vf $i
		done
	fi
}

backup_src() {
	cd $absdir/$1/$2
	srcdir=$absdir/$1/$2/src

	if [ -f PKGBUILD ]; then
		source /etc/makepkg.conf
		clean_var
		source PKGBUILD
		srcpath="$SRCDEST/$1"
		srcfile="$srcpath/$pkgname-$pkgver-$pkgrel.src.tar.lzma"
		if [ "$pkgbase" != "" ]; then
			srcfile="$srcpath/$pkgbase-$pkgver-$pkgrel.src.tar.lzma"
		fi

		if [ -f "$srcfile" ]; then
			echo "File $srcfile exists"
		elif [ ! -f "$srcfile" ]; then
			if [ -d "$srcdir" ]; then
				rm -R "$srcdir"
			fi
			oldsrcrel="$(find $srcpath -name "$pkgname-$pkgver-[0-9]*" | sort | head -1)"
			oldsrcver="$(find $srcpath -name "$pkgname-[0-9]*" | sort | head -1)"
			
			if [ "$oldsrcrel" != "" ]; then
				if [ "$oldsrcrel" != "$srcfile" ]; then
					echo "Removing $oldsrcrel"
					rm -vf $oldsrcrel
				fi
			elif [ "$oldsrcver" != "" ]; then
				if [ "$oldsrcver" != "$srcfile" ]; then
					echo "Removing $oldsrcver"
					rm -vf $oldsrcver
				fi
			fi

			if [ "$noextract" = "" ]; then
				makepkg -o --holdver --asroot
			else
				makepkg -g --holdver --asroot
			fi
			devel_sources
			if [ ! -d "$SRCDEST/$1" ]; then
				mkdir -p $SRCDEST/$1
			fi
			cd $absdir/$1
			if [ "$noextract" = "" ]; then
				remove_softlinks
			fi

			if [ "$(find $2/src -maxdepth 1 -type l)" ]; then
				for i in $(find $2/src -maxdepth 1 -type l); do
					cp -Lf $i $i-1
					rm $i
					mv -f $i-1 $i
				done 
			fi
			tar -c --lzma -f $srcfile $2			
			if [ -d "$srcdir" ]; then
				rm -R $srcdir
			fi
		fi
	else
		echo "No PKGBULD in $absdir/$1/$2"
		exit 1
	fi
}

if [ "$2" = "" ]; then
	if [ -d $absdir/$1 ]; then
		for i in $(find $absdir/$1 -name "PKGBUILD" | sed "s|$absdir/$1/||" | sed "s|/PKGBUILD||" | sort); do 
			if [ -f "$blacklist" -a "$(grep -Fx "$i" "$blacklist")" ]; then
				echo "Skipping $i"
				continue
			elif [ ! -f "$blacklist" ]; then
				backup_src $1 $i
			elif [ ! "$(grep -Fx "$i" "$blacklist")" ]; then
				backup_src $1 $i
			fi
		done
	else
		echo "$absdir/$1 doesn't exist"
		exit 1
	fi
elif [ "$2" != "" ]; then
	if [ -d $absdir/$1/$2 ]; then
			backup_src $1 $2
	else
		echo "$absdir/$1/$2 doesn't exist"
		exit 1
	fi
fi