#!/bin/bash -e
# Original author: Adam Thompson <athompson@merlin.mb.ca>
# Sponsoring employer: MERLIN <http://www.merlin.mb.ca>
# License: Unlicense <https://unlicense.org/> or Public Domain
# All warranties etc. disclaimed, code is provided as-is only.

OUTFILE=mbmap.gv

printf 'strict graph MBBGPNEIGHBORS {\n' > "${OUTFILE}"
printf '	ranksep="2.0 equally"\n' >> "${OUTFILE}"
printf '	rankdir="LR"\n' >> "${OUTFILE}"
printf '	subgraph clusterMB {\n' >> "${OUTFILE}"
printf '		fillcolor="white:yellow" style="radial"\n' >> "${OUTFILE}"

# AS394583 is the GWL ASN used in the UK - not relevant to us
curl -s -L https://bgpdb.ciscodude.net/api/asns/province/mb \
| egrep -v '^(394583)$' \
| ( while IFS='|' read ASN HANDLE NAME ACTIVE LOC; do  
	if [ "$ACTIVE" -eq 1 ]; then
		printf 'as%s [ label="AS%s\\n%s" ];\n'  "${ASN}"  "${ASN}" "${HANDLE}" >> "${OUTFILE}"

		curl -s -L https://bgpdb.ciscodude.net/api/asns/aspaths/$ASN \
		| perl -MList::MoreUtils -a -e 'if($F[0] =~ m/^\d+\z/ && $F[1] =~ m/^\d+\z/){@u=List::MoreUtils::uniq(@F);print "@u\n";}' \
		| sort -n \
		| uniq > $ASN.aspaths

	fi
	done

	# manually ensure these get put into the "Manitoba" subgraph
	printf 'as16395 [ label="AS16395\\nMBIX" ];\n' 
	printf 'as55073 [ label="AS55073\\nWPGIX" ];\n' 
	printf 'as30028 [ label="AS30028\\nMBNETSET" ];\n' 
) \
| sort -n \
| uniq >> "${OUTFILE}"

printf '	};\n' >> "${OUTFILE}"

# Eliminate Korean NREN paths, don't care about them.
# Remove MBIX from the path, it's artificially inserted in the first place
# Ditto for WPGIX
cat *.aspaths \
| egrep -v '( 4766 )' \
| sed -e 's/ 16395 //;s/ 55073 //' \
| perl -MList::MoreUtils -a -e 'if($F[0] =~ m/^\d+\z/ && $F[1] =~ m/^\d+\z/){@u=List::MoreUtils::uniq(@F);print "@u\n";}' \
| sort -n \
| uniq > aspaths.merged
rm *.aspaths

# echo(1) turns a multi-line list into a single shell-style list of tokens
# Not sure why this was needed, now... it's the data-centric version of "eval"
MBASNS=$(echo $( curl -s -L https://bgpdb.ciscodude.net/api/asnlist/province/mb ) )

# manually tag some ASes as Canadian, or local, or duplicated
tr ' ' '\n' < aspaths.merged \
| sort \
| uniq \
| while read ASN ; do
	if [[ "${MBASNS}" =~ (^|[[:space:]])${ASN}($|[[:space:]]) ]] ; then
		true	# already there, do nothing
	else
		HANDLE=$( whois -h whois.cymru.com as$ASN | tail -1 | cut -d' ' -f1 )
		case "${ASN}" in
		16796)	# me!
			printf 'as%s [ label="AS%s\\n%s" fillcolor="white:blue" style="radial" ];\n' "${ASN}"  "${ASN}" "${HANDLE}" >> "${OUTFILE}"
			;;
		16395|55073|30028)	# already did these in the MB section above, skip 'em here
			;;
		6509|803|812|15290|20161|22652|577|16395|6327|55073|6461)	# known Canadian ASes
			printf 'as%s [ label="AS%s\\n%s" fillcolor="white:red" style="radial" ];\n' "${ASN}"  "${ASN}" "${HANDLE}" >> "${OUTFILE}"
			;;
		6939)	# ASes known to have POPs in Winnipeg
			printf 'as%s [ label="AS%s\\n%s" fillcolor="white:green" style="radial" ];\n' "${ASN}"  "${ASN}" "${HANDLE}" >> "${OUTFILE}"
			;;
		*)	# anyone else
			printf 'as%s [ label="AS%s\\n%s" ];\n' "${ASN}"  "${ASN}" "${HANDLE}" >> "${OUTFILE}"
			;;
		esac
	fi
done

sed -e 's/^/as/;s/ / -- as/g;s/$/;/' aspaths.merged >> "${OUTFILE}"
printf '}\n' >> "${OUTFILE}"
rm aspaths.merged

dot -Tpdf -O "${OUTFILE}"

# vim:ts=4 sw=4 ai si nu:
