#!/bin/bash -e

contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]] && exit 0  || exit 1 ;
}

# first try OpenBSD, then Linux/WSL
NCPUS=$(sysctl -n hw.ncpuonline 2>/dev/null || egrep '^processor\s+: ' /proc/cpuinfo | wc -l)
BGPSCANNER="/home/athompson/bgpscanner/build/bgpscanner"

# Get our RIB

# Grab our RIB separately, not an HTTP request from Theo, because
# we have NREN visibility that isn't in Theo's dataset.
# Also invert the aspath to match external view.
curl -s -L https://bgpmirror.merlin.mb.ca/bgplg/mrt/rib-dump.mrt \
| /home/athompson/bgpscanner/build/bgpscanner | awk -F\| '$1="=" {print 16796,$3}' \
| perl -MList::MoreUtils -a -e '@u=List::MoreUtils::uniq(reverse(@F));print "@u\n";' \
| sort -n \
| uniq > MERLIN.aspaths

printf 'strict digraph MBBGPNEIGHBORS {\n' > mbmap.gv
printf '	ranksep="2.0 equally"\n' >> mbmap.gv
printf '	rankdir="LR"\n' >> mbmap.gv


curl -s -L https://bgpdb.ciscodude.net/api/asns/province/mb \
| ( while IFS='|' read ASN HANDLE NAME ACTIVE LOC; do  
	if [ "$ACTIVE" -eq 1 ]; then
		echo "as$ASN [ label=\"AS$ASN\\n$HANDLE\" ];"

		curl -s -L https://bgpdb.ciscodude.net/api/asns/aspaths/$ASN \
		| perl -MList::MoreUtils -a -e 'if($F[0] =~ m/^\d+\z/ && $F[1] =~ m/^\d+\z/){@u=List::MoreUtils::uniq(@F);print "@u\n";}' \
		| sort -n \
		| uniq > $ASN.aspaths

	fi
done ) | sort -n | uniq >> mbmap.gv


cat *.aspaths \
| perl -MList::MoreUtils -a -e 'if($F[0] =~ m/^\d+\z/ && $F[1] =~ m/^\d+\z/){@u=List::MoreUtils::uniq(@F);print "@u\n";}' \
| sort -n \
| uniq > aspaths.merged
rm *.aspaths


tr ' ' '\n' < aspaths.merged \
| sort \
| uniq \
| while read ASN ; do
	set -x
	if grep -q "as${ASN} \[ label" mbmap.gv ; then
		true	# do nothing
	else
		HANDLE=$( whois -h whois.cymru.com as$ASN | tail -1 | cut -d' ' -f1 )
		echo "as$ASN [ label=\"AS$ASN\\n$HANDLE\" ];" >> mbmap.gv
	fi
done


sed -e 's/^/as/;s/ / -> as/g;s/$/;/' aspaths.merged >> mbmap.gv
printf '}\n' >> mbmap.gv

dot -Tpdf -O mbmap.gv

# vim:ts=4 sw=4 ai si nu:
