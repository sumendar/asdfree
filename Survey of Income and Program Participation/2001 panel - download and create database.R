# analyze us government survey data with the r language
# survey of income and program participation
# 2001 panel
# 9 core waves, 9 wave-specific replicate weights, 9 topical modules, 
# 3 panel year replicate weights, 3 calendar year replicate weights, 1 longitudinal weights
# 1 household public use extract, 1 welfare reform topical module

# if you have never used the r language before,
# watch this two minute video i made outlining
# how to run this script from start to finish
# http://www.screenr.com/Zpd8

# anthony joseph damico
# ajdamico@gmail.com

# if you use this script for a project, please send me a note
# it's always nice to hear about how people are using this stuff

# for further reading on cross-package comparisons, see:
# http://journal.r-project.org/archive/2009-2/RJournal_2009-2_Damico.pdf


#####################################################################################################################
# Download and Create a Database with the 2001 Panel of the Survey of Income and Program Participation files with R #
#####################################################################################################################


# set your working directory.
# all SIPP data files will be stored here
# after downloading and importing.
# use forward slashes instead of back slashes

setwd( "C:/My Directory/SIPP/" )


# remove the # in order to run this install.packages line only once
# install.packages( c( "RSQLite" , "SAScii" ) )


SIPP.dbname <- "SIPP01.db"										# choose the name of the database (.db) file on the local disk

sipp.core.waves <- 1:9												# either choose which core survey waves to download, or set to NULL
sipp.replicate.waves <- 1:9											# either choose which replicate weight waves to download, or set to NULL
sipp.topical.modules <- 1:9											# either choose which topical modules to download, or set to NULL
sipp.longitudinal.weights <- TRUE									# set to FALSE to prevent download
sipp.household.extract <- TRUE										# set to FALSE to prevent download
sipp.welfare.reform.module <- TRUE									# set to FALSE to prevent download
sipp.cy.longitudinal.replicate.weights <- paste0( 'cy' , 1:3 )		# 1-3 reads in 2001-2003
sipp.pnl.longitudinal.replicate.weights <- paste0( 'pnl' , 1:3 )	# 1-3 reads in 2001-2003

############################################
# no need to edit anything below this line #

# # # # # # # # #
# program start #
# # # # # # # # #


require(RSQLite) 	# load RSQLite package (creates database files in R)
require(SAScii) 	# load the SAScii package (imports ascii data with a SAS script)



##############################################################################
# function to fix sas input scripts where census has the incorrect column type
fix.ct <-
	function( sasfile ){
		sas_lines <- readLines( sasfile )

		# ssuid should always be numeric (it's occasionally character)
		sas_lines <- gsub( "SSUID $" , "SSUID" , sas_lines )
		
		# ctl_date and lgtwttyp contain strings not numbers
		sas_lines <- gsub( "CTL_DATE" , "CTL_DATE $" , sas_lines )
		sas_lines <- gsub( "LGTWTTYP" , "LGTWTTYP $" , sas_lines )

		# create a temporary file
		tf <- tempfile()
		
		# write the updated sas input file to the temporary file
		writeLines( sas_lines , tf )

		# return the filepath to the temporary file containing the updated sas input script
		tf
	}
##############################################################################

#######################################################	
# function to download scripts directly from github.com
# http://tonybreyal.wordpress.com/2011/11/24/source_https-sourcing-an-r-script-from-github/
source_https <- function(url, ...) {
  # load package
  require(RCurl)

  # parse and evaluate each .R script
  sapply(c(url, ...), function(u) {
    eval(parse(text = getURL(u, followlocation = TRUE, cainfo = system.file("CurlSSL", "cacert.pem", package = "RCurl"))), envir = .GlobalEnv)
  })
}
#######################################################

# load the read.SAScii.sql function (a variant of read.SAScii that creates a database directly)
source_https( "https://raw.github.com/ajdamico/usgsd/master/read.SAScii.sql.R" )

# set the locations of the data files on the ftp site
SIPP.core.sas <-
	"http://smpbff2.dsd.census.gov/pub/sipp/2001/p01puw1.sas"
	
SIPP.replicate.sas <-
	"http://smpbff2.dsd.census.gov/pub/sipp/2001/rw01wx.sas"
	
SIPP.longitudinal.replicate.sas <-
	"http://smpbff2.dsd.census.gov/pub/sipp/2001/repwgt_sas_input.sas"

# if the household extract flag has been set to TRUE above..
if ( sipp.household.extract ){

	# the census SIPP FTP site does not have a SAS input script,
	# so create one using the dictionary at
	# http://smpbff2.dsd.census.gov/pub/sipp/2001/hhpuw1d.txt

	# write an example SAS import script using the dash method
	sas.import.with.at.signs <-
		"INPUT
			@1   SSUID   12.
			@13   UHOWLGMT   2.
			@15   UHOWLGYR   4.
			@19   UWHNAPMT   2.
			@21   UWHNAPYR   4.
			@25   UWAITLST   1.
		;"
		
	# create a temporary file
	sas.import.with.at.signs.tf <- tempfile()
	# write the sas code above to that temporary file
	writeLines ( sas.import.with.at.signs , con = sas.import.with.at.signs.tf )

	# end of fake SAS input script creation #
	
	# add the longitudinal weights to the database in a table 'hh' (household)
	read.SAScii.sql(
		"http://smpbff2.dsd.census.gov/pub/sipp/2001/hhldpuw1.zip" ,
		fix.ct( sas.import.with.at.signs.tf ) ,
		# note no beginline = parameter in this read.SAScii.sql() call
		zipped = T ,
		tl = TRUE ,
		tablename = "hh" ,
		dbname = SIPP.dbname
	)
}
	
# if the welfare reform module flag has been set to TRUE above..
if ( sipp.welfare.reform.module ){

	# add the longitudinal weights to the database in a table 'wf' (welfare)
	read.SAScii.sql(
		"http://smpbff2.dsd.census.gov/pub/sipp/2001/p01putm8x.zip" ,
		fix.ct( "http://smpbff2.dsd.census.gov/pub/sipp/2001/p01putm8x.sas" ) ,
		beginline = 5 ,
		zipped = T ,
		tl = TRUE ,
		tablename = "wf" ,
		dbname = SIPP.dbname
	)
}
	
# if the longitudinal weights flag has been set to TRUE above..
if ( sipp.longitudinal.weights ){

	# the census SIPP FTP site does not have a SAS input script,
	# so create one using the dictionary at
	# http://smpbff2.dsd.census.gov/pub/sipp/2001/lgtwt01d.txt

	# write an example SAS import script using the dash method
	sas.import.with.at.signs <-
		"INPUT
			@1 	   LGTKEY      8.
			@9      SPANEL       4.
			@13      SSUID      12.
			@25      EPPPNUM      4.
			@29      LGTPNWT1   10.
			@39      LGTPNWT2   10.
			@49      LGTPNWT3   10.
			@59      LGTCY1WT   10.
			@69      LGTCY2WT   10.
			@79      LGTCY3WT   10.
		;"
		
	# create a temporary file
	sas.import.with.at.signs.tf <- tempfile()
	# write the sas code above to that temporary file
	writeLines ( sas.import.with.at.signs , con = sas.import.with.at.signs.tf )

	# end of fake SAS input script creation #
	
	# add the longitudinal weights to the database in a table 'w9'
	read.SAScii.sql(
		"http://smpbff2.dsd.census.gov/pub/sipp/2001/lgtwgt2001w9.zip" ,
		fix.ct( sas.import.with.at.signs.tf ) ,
		# note no beginline = parameter in this read.SAScii.sql() call
		zipped = T ,
		tl = TRUE ,
		tablename = "w9" ,
		dbname = SIPP.dbname
	)
}
	
# loop through each core wave..
for ( i in sipp.core.waves ){

	# figure out the exact ftp path of the .zip file
	SIPP.core <-
		paste0( "http://smpbff2.dsd.census.gov/pub/sipp/2001/l01puw" , i , ".zip" )

	# add the core wave to the database in a table w#
	read.SAScii.sql (
			SIPP.core ,
			fix.ct( SIPP.core.sas ) ,
			beginline = 5 ,
			zipped = T ,
			tl = TRUE ,
			tablename = paste0( "w" , i ) ,
			dbname = SIPP.dbname
		)
}

# loop through each replicate weight wave..
for ( i in sipp.replicate.waves ){

	# figure out the exact ftp path of the .zip file
	SIPP.rw <-
		paste0( "http://smpbff2.dsd.census.gov/pub/sipp/2001/rw01w" , i , ".zip" )

	# add the wave-specific replicate weight to the database in a table rw#
	read.SAScii.sql (
			SIPP.rw ,
			fix.ct( SIPP.replicate.sas ) ,
			beginline = 5 ,
			zipped = T ,
			tl = TRUE ,
			tablename = paste0( "rw" , i ) ,
			dbname = SIPP.dbname
		)
}

# loop through each topical module..
for ( i in sipp.topical.modules ){

	# figure out the exact ftp path of the .zip file
	SIPP.tm <-
		paste0( "http://smpbff2.dsd.census.gov/pub/sipp/2001/p01putm" , i , ".zip" )

	# figure out the exact ftp path of the .sas file
	SIPP.tm.sas <-
		paste0( "http://smpbff2.dsd.census.gov/pub/sipp/2001/p01putm" , i , ".sas" )
		
	# add each topical module to the database in a table tm#
	read.SAScii.sql (
			SIPP.tm ,
			fix.ct( SIPP.tm.sas ) ,
			beginline = 5 ,
			zipped = T ,
			tl = TRUE ,
			tablename = paste0( "tm" , i ) ,
			dbname = SIPP.dbname
		)
}

# loop through each longitudinal replicate weight file..
for ( i in c( sipp.cy.longitudinal.replicate.weights , sipp.pnl.longitudinal.replicate.weights ) ){

	# figure out the exact ftp path of the .zip file
	SIPP.lrw <-
		paste0( "http://smpbff2.dsd.census.gov/pub/sipp/2001/lgtwgt" , i , ".zip" )
		
	# add each longitudinal replicate weight file to the database in a table cy1-3 or pnl1-3
	read.SAScii.sql (
			SIPP.lrw ,
			fix.ct( SIPP.longitudinal.replicate.sas ) ,
			beginline = 5 ,
			zipped = T ,
			tl = TRUE ,
			tablename = i ,
			dbname = SIPP.dbname
		)
}
# the current working directory should now contain one database (.db) file

# once complete, this script does not need to be run again.
# instead, use one of the survey of income and program participation analysis scripts
# which utilize this newly-created database (.db) files


# for more details on how to work with data in r
# check out my two minute tutorial video site
# http://www.twotorials.com/