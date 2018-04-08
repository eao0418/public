<#
.SYNOPSIS
This is a script for comparing known files to questioned files.

.DESCRIPTION
A script for comparing files with a known hash to questioned documents.  
The goal here is to obviously determine which files were altered and which ones were not.

The following headings must be supplied: 
FileName, ProvidedHash, Algorithm


Written by Aaron Randolph and provided AS IS with NO WARRANTY.

.PARAMETER InputFile
Mandatory. The CSV that contains the inputs for the script. 

.PARAMETER InputDirectory
Not Mandatory if the script runs from the same directory as the files.

.EXAMPLE
.\GetHashes.ps1 -InputFile .\Inputs.csv -DocumentDirectory "$($(Get-Location).path)\Questioned_Documents\"
#>
Param(
    # The CSV Input File
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $InputFile, 
    # The Directory of the Questioned Documents
    [Parameter(Mandatory = $false)]
    [System.String]
    $DocumentDirectory
)

class outfile {
    [System.String]$FileName
    [System.String]$ProvidedHash
    [System.String]$Alg
    [System.String]$ComputedHash
    [System.String]$MatchResult
}

function validateinput {
    Param(
        # The CSV Input File
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InputFile, 
        # The Directory of the Questioned Documents
        [Parameter(Mandatory = $false)]
        [System.String]
        $DocumentDirectory
    )
    # Check the first parameter to make sure it is valid. 
    try {
        Resolve-Path -Path $InputFile -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Host -ForegroundColor Red "The Input File path could not be resolved. Check the value you provided for 'InputFile' and try again."
        exit 1
    }
    if ($DocumentDirectory.Length -gt 0) {
        try {
            Resolve-Path -Path $DocumentDirectory -ErrorAction Stop
            [System.Boolean]$docdir = $true
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            Write-Host -ForegroundColor Red "The parameter you specified for 'DocumentDirectory' could not be reoslved.  Please check your value and try again"
            exit 1
            [System.Boolean]$docdir = $false
        }
    }
    return [System.Boolean]$docdir
}
function Hashfiles {
    # Function Parameters
    param(
        # The CSV input
        [Parameter(Mandatory = $true)]
        [System.Object]
        $csv, 
        # Document Directory Parameter
        [Parameter(Mandatory = $true)]
        [System.Boolean]
        $docdir
    )
    # Create an object to collect each hashed value
    $hashlist = New-Object System.Collections.Generic.List[outfile]
    # Iterate over each line in the csv
    foreach ($line in $csv) {
        try {
            # Use the path for the document directory if it is provided.
            if ($docdir -eq $true) {
                $newhash = (Get-FileHash -Algorithm $line.Alg -Path "$($DocumentDirectory)\$($line.FileName)" -ErrorAction Stop).hash
            }
            else {
                $newhash = (Get-FileHash -Algorithm $line.Alg -Path ".\$($line.FileName)" -ErrorAction Stop).hash
            }
            $temp = New-Object outfile
            $temp.FileName = $line.FileName
            $temp.ProvidedHash = $line.ProvidedHash
            $temp.Alg = $line.Alg
            $temp.ComputedHash = $newhash
            if ($newhash -eq $line.ProvidedHash) {
                $temp.MatchResult = $true
            }
            else {
                $temp.MatchResult = $false
            }
            $hashlist.Add($temp)

        }
        catch [System.Management.Automation.ItemNotFoundException] {
            $temp = New-Object outfile
            $temp.FileName = $line.FileName
            $temp.ProvidedHash = $line.ProvidedHash
            $temp.Alg = $line.Alg
            $temp.ComputedHash = $Error[0]
            if ($newhash -eq $line.ProvidedHash) {
                $temp.MatchResult = $true
            }
            else {
                $temp.MatchResult = $false
            }
            $hashlist.Add($temp)
        }
    }
    return $hashlist
}

function ExportObject {
    param(
        # The object to export to a CSV file
        [Parameter(Mandatory = $true)]
        $outputobject
    )
    $path = (Get-Location).Path
    $closed = $true
    while ($closed) {
        try {
            $outputobject | Export-Csv .\Hashoutput.csv -NoTypeInformation -ErrorAction Stop
            Write-Host -ForegroundColor Cyan "Your file was exported to $($path)\Hashoutput.csv"
            $closed = $false
        }
        catch [System.IO.IOException] {
            Write-Host -ForegroundColor Yellow "The csv is open.  Please close $($path)\Hashoutput.csv."
            Read-Host -Prompt "Press Enter When you have Closed the CSV"
            $closed = $true
        }
    }
}

# Validate that our inputs are good
[System.Boolean]$docdir = validateinput -InputFile $InputFile -DocumentDirectory $DocumentDirectory
# Import CSV file.
$csv = Import-Csv -Path $InputFile -Header @("FileName", "ProvidedHash", "Alg") | Select-Object -Skip 1
# Get the hashes for our files
$hashes = Hashfiles -csv $csv -docdir $docdir
ExportObject -outputobject $hashes
