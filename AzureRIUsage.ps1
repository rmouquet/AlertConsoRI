#Récupération de la date
$datestart=Get-date((Get-date).AddDays(-2)) -Format "yyyy-MM-dd"
$dateend=Get-date((Get-date).AddDays(-1)) -Format "yyyy-MM-dd"


Import-Module -Name Az.reservations
#Création d'une liste de RI order
$RIorderList=@()

#Récupération des souscriptions
$subs=Get-AzSubscription
#Parcours des souscriptions
foreach($sub in $subs){
    Select-AzSubscription -SubscriptionId $sub.id
    #Récupération des RIOrders de la souscription
    $order=Get-AzReservationOrderId
    $reservationorders=($order.AppliedReservationOrderId)
    foreach ($reservationorder in $reservationorders){
        $length=$reservationorder.length
        $reservationorderid=$reservationorder.Substring($length -36, 36)
        #On teste si on a déja référencé cet achat, en définitive si la RI est en shared ou en single souscription
            if($RIorderList.id -notcontains $reservationorderid){
                $newid=([PSCustomObject]@{id = "$reservationorderid"})
                $RIorderList += $newid
            }
    }
}

#Parcours des RIOrders
foreach($orderid in $RIorderList){
    $length = $orderid.ID.length
    $orderid=$orderid.ID.Substring($length -36, 36)
    #Récupération des RIs
    $ris=Get-AzReservation -ReservationOrderId $orderid
    #Parcours des RIs
    foreach($ri in $ris){
        $lengthri = $ri.Id.length
        $riid=$ri.Id.Substring($lengthri -36, 36)
        #Récupération de la conso moyenne de la veille
        $riconso=Get-azConsumptionReservationSummary -Grain daily -ReservationOrderId $orderid -ReservationId $riid -Startdate $datestart -EndDate $dateend
        $id=$riconso.ReservationId[1]
        $pourcent=$riconso.AveUtilizationPercentage[1]

        #Définition du Scope de la RI
        if ($ri.AppliedScopes){
            $lengthsub=$ri.AppliedScopes.length
            $scope=(Get-AzSubscription -SubscriptionId ($ri.AppliedScopes).Substring($lengthsub -36, 36)).Name

        }else{
            $scope="un périmètre partagé"
        }
        #Message de consommationRI
        Write-Host "La consomation de la RI $id, appliquée sur $scope pour la journée d'hier est de $pourcent%"


        #Test Consomation RI Satisfaisant ou pas ? Le niveau est ajustable en fonction des besoins
        if ($pourcent -ige 90){
            Write-Host "L'utilisation est convenable"
        }else {
            Write-Host "Attention l'utilisation pour la RI $id n'est pas optimale (infèrieur à 90%)"
            ###################################################
            ##Ajouter ici d'autres actions de remédiations :)##
            ##Send-MailMessage -to "to@yourdomain.com" -from "from@yourdomain.com" -Body "You have an alert on you ri $id" -SmtpServer "yoursmtpserver.com"
            ###################################################
        }
    }
}
