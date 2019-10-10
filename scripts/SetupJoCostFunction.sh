#!/bin/bash
#
# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # 
#                       Unix Script Documentation 
# 
# Script Name        :
#
# Script Description :
#
# Details            :
#
# Author             :
#
# History Log        :
#
# TODO               : Optimize the two inputs
#
# * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # * # 
# set -x

while getopts "i:d:" opt; do
   case $opt in
      i) yamlfile=("$OPTARG");;
      d) RUNDIRC=("$OPTARG");;
   esac
done
shift $((OPTIND -1))

## Setup Jo cost function
##-----------------------

DATADIR=${RUNDIRC}/Data

mkdir -p ${DATADIR}

obsdatabase=${DATADIR}/${CDATE} 
echo "obsdatabase="$obsdatabase

# Add adt obs to Jo
obsfile=$obsdatabase/ioda.adt.${DA_SLOT_LEN}h.nc
echo $obsfile
if [ -f $obsfile ]; then
   echo "Adding ADT to Jo cost function"
   ln -sf ${obsfile} ${DATADIR}/adt.nc
   sed -e '/ADT_JO/{r '${RUNDIRC}'/yaml/adt.yml' -e 'd}' ${yamlfile}> 3dvartmp.yml 
   cp 3dvartmp.yml ${yamlfile}
   rm 3dvartmp.yml
else
   echo "Not assimilating ADT"
fi

# Add icec obs to Jo (f285-f286 SSMI/SSMIS)
obsfile=$obsdatabase/ioda.icec.cat_l2.emc.${DA_SLOT_LEN}h.nc
echo $obsfile
if [ -f $obsfile ]; then
   echo "Adding ice concentration to Jo cost function"
   # TODO: Subsample elsewhere
   cp ${obsfile} ${obsdatabase}/ioda.icec.cat_l2.emc_LARGE.nc
   module load nco
   # Create record dim
   ncks --mk_rec_dmn nlocs ${obsdatabase}/ioda.icec.cat_l2.emc_LARGE.nc ${obsdatabase}/icec-tmp.nc
   # Subsample
   ncks -F -d nlocs,1,,50 ${obsdatabase}/icec-tmp.nc ${DATADIR}/ioda.icec.cat_l2.emc.nc
   rm ${obsdatabase}/sst-tmp.nc
   rm ${obsdatabase}/ioda.sst.${sst_source}_LARGE.nc

   sed -e '/ICEC_emcice_JO/{r '${RUNDIRC}'/yaml/icec.cat_l2.emc.yml' -e 'd}' ${yamlfile}> 3dvartmp.yml 
   cp 3dvartmp.yml ${yamlfile}
   rm 3dvartmp.yml
else
   echo "Not assimilating emc icec"
fi

# Add ghrsst to Jo.
listofsst="windsat_l3u.ghrsst \
           gmi_l3u.ghrsst \
           amsr2_l3u.ghrsst \
           avhrrmta_l3u.nesdis \
           avhrr19_l3u.nesdis"
for sst_source in $listofsst; do
   obsfile=$obsdatabase/ioda.sst.${sst_source}.${DA_SLOT_LEN}h.nc 
   echo $obsfile
   if [ -f $obsfile ]; then
      echo "Adding $sst_source SST to Jo cost function"
      case $sst_source in 
         "avhrrmta_l3u.nesdis")
            subsample=true
            skip=500
            ;;
         "avhrr19_l3u.nesdis")
            subsample=true
            skip=500
            ;;
         "windsat_l3u.ghrsst")
            subsample=true
            skip=10
            ;;
      esac

      if [ $subsample ]; then
         echo "Subsampling $sst_source SST"
         # TODO: Subsample elsewhere
	 cp ${obsfile} ${obsdatabase}/ioda.sst.${sst_source}_LARGE.nc
         module load nco
         # Create record dim
         ncks --mk_rec_dmn nlocs ${obsdatabase}/ioda.sst.${sst_source}_LARGE.nc ${obsdatabase}/sst-tmp.nc
         # Subsample
         ncks -F -d nlocs,1,,$skip ${obsdatabase}/sst-tmp.nc ${DATADIR}/ioda.sst.${sst_source}.nc
         rm ${obsdatabase}/sst-tmp.nc
         rm ${obsdatabase}/ioda.sst.${sst_source}_LARGE.nc   
      else
         ln -sf ${obsfile} ${DATADIR}/ioda.sst.${sst_source}.nc
      fi
      echo SST_${sst_source}_JO
      sed -e '/SST_'${sst_source}'_JO/{r '${RUNDIRC}'/yaml/sst.'${sst_source}'.yml' -e 'd}' ${yamlfile}> 3dvartmp.yml 
      cp 3dvartmp.yml ${yamlfile}
      rm 3dvartmp.yml
   else
     echo "Not assimilating $sst_source SST"
   fi
done

# Add insitu profiles to Jo
obsfile=$obsdatabase/ioda.profile.${DA_SLOT_LEN}h.nc 
if [ -f $obsfile ]; then
   echo "Adding Profiles to Jo cost function"
   ln -sf ${obsfile} ${DATADIR}/prof.nc
   sed -e '/INSITU_JO/{r '${RUNDIRC}'/yaml/profile.yml' -e 'd}' ${yamlfile}> 3dvartmp.yml 
   cp 3dvartmp.yml ${yamlfile}
   rm 3dvartmp.yml
else
   echo "Not assimilating profiles"
fi
