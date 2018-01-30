# geni-download
A few scripts to download the data from Geni. ***Users must get myheritage.com permission before any large download of data from Geni.com*** 

### usage:
perl fetch_geni_sitemap.pl --output outputs.txt

### Next, in the command line:

cut -f2 outputs.txt \
    | sed 's/^.*profile-//' > all-profiles-guid.unsorted.txt

sort -u -V all-profiles-guid.unsorted.txt > all-profiles-guid.sorted.txt

mkdir -p chunks

cat all-profiles-guid.sorted.txt \
 | awk 'NR%50==0 { print $0; next } { printf "%s,", $0 }' \
 | sed '$s/,$//' \
 | split -d -l 2000 -a 4 - chunks/profile-guids.
 
FIELDS="about_me,baptism,big_tree,birth,block_exists,burial,cause_of_death,claimed,created_at,creator,curator,current_residence,death,display_name,documents_updated_at,email,first_name,gender,get_email,guid,id,is_alive,language,last_name,locked,maiden_name,managers,master_profile,merge_note,merge_pending,merged_into,middle_name,mugshot_urls,name,nicknames,occupation,phone_numbers,photos_updated_at,premium_start_date,profile_url,public,relationship,requested_merges,suffix,unions,updated_at,url,videos_updated_at"


for i in chunks/profile-guids.* ; do
    chunk=${i#chunks/profile-guids.}
    mkdir -p results/$chunk/
    line=1
    echo "Starting new chunk $chunk (infile = $i)"
    cat "$i" | while read IDS ; do
        outfile="results/$chunk/ids.line-$line.json"
        first_guid=${IDS%%,*}
        echo "Fetching chunk $chunk, line $line, first_guid=$first_guid (infile=$i  outfile=$outfile)"
        line=$((line+1))

        URL="https://www.geni.com/api/profile?ids=$IDS&fields=$FIELDS"

        if test -e "$outfile" ; then
            echo "Skipping existing file: $outfile"
            continue
        fi

        if curl --silent -k "$URL" > "$outfile.t" ; then
            mv "$outfile.t" "$outfile"
        else
            echo "warning: failed on URL '$URL'"
            rm "$outfile.t"
        fi
   done
done


### the JSON fields are in the results folder. You will need to parse them and get family connections.
