Describe "Get-CmAzResourceName Tests" {

    BeforeAll {
        $projectRoot = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project\Integration"
        $location = "UK South"
        $architecture = "Core"
    }

    Context "No context has been set" {

        BeforeAll {
            Clear-CmAzContext
        }

        It "Should fail when no CmAzContext has been set" {
            {
                Get-CmAzResourceName -Resource "ResourceGroup" -Architecture $architecture -Location $location -Name "Keys"
            } | Should -Throw "No Cloudmarque Azure context is in place, please run Set-CmAzContext before running this command."
        }
    }

    Context "Assert resources are named correctly" {

        BeforeAll {
            Set-CmAzContext -Environment "Development" -ProjectRoot $projectRoot
        }

        It "Should not have double separators" {
            $name = Get-CmAzResourceName -Resource "Sample2" -Architecture $architecture -Location $location -Name "MyApp"
            $name | Should -Be "default-myapp-dev-uks-5c1753d6"
        }

        It "Should not have seperator before domain name" {
            $name = Get-CmAzResourceName -Resource "WebApp" -Architecture $architecture -Location $location -Name "MyWebApp"
            $name | Should -Not -Contain "-.azurewebsites.net"
        }

        It "Should not have name length greater then defined" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture $architecture -Location $location -Name "MyWindows"
            $name.length | Should -Not -BeGreaterThan 15
        }
    }

    Context "Should report bad parameters" {

        It "Should warn about locations that don't exist" {
            {
                Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "IaaS" -Location "Timbuktoo" -Name "MyApp"
            } | Should -Throw "No location naming convention found in _names\locations.yml for 'Timbuktoo'"
        }

        It "Should fail when using generators that don't exist" {
            {
                Get-CmAzResourceName -Resource "Sample1" -Architecture "IaaS" -Location "Timbuktoo" -Name "MyApp"
            } | Should -Throw "No location naming convention found in _names\locations.yml for 'Timbuktoo'"
        }

        It "Should tolerate incorrectly cased resources" {
            $name = Get-CmAzResourceName -Resource "resourceGroup" -Architecture $architecture -Location $location -Name "Keys"
            $name | Should -Be "rg-keys-core-cebe9fa3"
        }
    }
    Context "Getting correct build ID operations" {

        It "Should append build ID" {
            $name = Get-CmAzResourceName -Resource "Budget" -Architecture $architecture -Location $location -Name "MyBudget" -IncludeBuild
            $name | Should -Be "bud-mybudget-dev-uks-bbef0c49-001"
        }

        It "Should get a VirtualMachine name with build ID" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture $architecture -Location $location -Name "MyWindows" -IncludeBuild
            $name | Should -Be "vmmywindows001"
        }
    }

    Context "Get names from the script" {

        It "Should get a ResourceGroup name" {
            $name = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture $architecture -Location $location -Name "MyResourceGroup"
            $name | Should -Be "rg-myresourcegroup-core-b3760842"
        }

        It "Should get a VirtualMachine name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture $architecture -Location $location -Name "MyWindows"
            $name | Should -Be "vmmywindowsa941"
        }

        It "Should get a VirtualMachineLinux name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineLinux" -Architecture $architecture -Location $location -Name "MyVirtualMachineLinux"
            $name | Should -Be "vmmyvirtualmachinelinux78361ba6"
        }

        It "Should get a VirtualMachineScaleset name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineScaleset" -Architecture $architecture -Location $location -Name "Scaleset"
            $name | Should -Be "vmssscalesetc29"
        }

        It "Should get a VirtualMachineScalesetLinux name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineScalesetLinux" -Architecture $architecture -Location $location -Name "MyVirtualMachineScalesetLinux"
            $name | Should -Be "vmssmyvirtualmachinescalesetlinux7785511e"
        }

        It "Should get a PolicyDefinition name" {
            $name = Get-CmAzResourceName -Resource "PolicyDefinition" -Architecture $architecture -Location $location -Name "MyPolicyDefinition"
            $name | Should -Be "policy-mypolicydefinition-dev-uks-c01ca77c"
        }

        It "Should get a APImanagementServiceInstance name" {
            $name = Get-CmAzResourceName -Resource "APImanagementServiceInstance" -Architecture $architecture -Location $location -Name "MyAPImanagementServiceInstance"
            $name | Should -Be "apim-myapimanagementserviceinstance-dev-uks-5adcdcab"
        }

        It "Should get a VirtualNetwork name" {
            $name = Get-CmAzResourceName -Resource "VirtualNetwork" -Architecture $architecture -Location $location -Name "MyVirtualNetwork"
            $name | Should -Be "vnet-myvirtualnetwork-dev-uks-df5dee74"
        }

        It "Should get a Subnet name" {
            $name = Get-CmAzResourceName -Resource "Subnet" -Architecture $architecture -Location $location -Name "MySubnet"
            $name | Should -Be "snet-mysubnet-dev-uks-52524038"
        }

        It "Should get a Budget name" {
            $name = Get-CmAzResourceName -Resource "Budget" -Architecture $architecture -Location $location -Name "MyBudget"
            $name | Should -Be "bud-mybudget-dev-uks-bbef0c49"
        }

        It "Should get a AutomationSchedule name" {
            $name = Get-CmAzResourceName -Resource "AutomationSchedule" -Architecture $architecture -Location $location -Name "MyAutomationSchedule"
            $name | Should -Be "atshed-myautomationschedule-dev-uks-13fe9332"
        }

        It "Should get a NetworkInterfaceCard name" {
            $name = Get-CmAzResourceName -Resource "NetworkInterfaceCard" -Architecture $architecture -Location $location -Name "MyNetworkInterfaceCard"
            $name | Should -Be "nic-mynetworkinterfacecard-dev-uks-d3a7f144"
        }

        It "Should get a PublicIPAddress name" {
            $name = Get-CmAzResourceName -Resource "PublicIPAddress" -Architecture $architecture -Location $location -Name "MyPublicIPAddress"
            $name | Should -Be "pip-mypublicipaddress-dev-uks-db600510"
        }

        It "Should get a LoadbalancerInternal name" {
            $name = Get-CmAzResourceName -Resource "LoadbalancerInternal" -Architecture $architecture -Location $location -Name "MyLoadbalancerInternal"
            $name | Should -Be "lbi-myloadbalancerinternal-dev-uks-5dba7d4b"
        }

        It "Should get a LoadbalancerExternal name" {
            $name = Get-CmAzResourceName -Resource "LoadbalancerExternal" -Architecture $architecture -Location $location -Name "MyLoadbalancerExternal"
            $name | Should -Be "lbe-myloadbalancerexternal-dev-uks-6a9269b3"
        }

        It "Should get a NetworkSecurityGroup name" {
            $name = Get-CmAzResourceName -Resource "NetworkSecurityGroup" -Architecture $architecture -Location $location -Name "MyNetworkSecurityGroup"
            $name | Should -Be "nsg-mynetworksecuritygroup-e856f8dd"
        }

        It "Should get a ApplicationSecurityGroup name" {
            $name = Get-CmAzResourceName -Resource "ApplicationSecurityGroup" -Architecture $architecture -Location $location -Name "MyApplicationSecurityGroup"
            $name | Should -Be "asg-myapplicationsecuritygroup-dev-uks-fa2ec1a4"
        }

        It "Should get a LocalNetworkGateway name" {
            $name = Get-CmAzResourceName -Resource "LocalNetworkGateway" -Architecture $architecture -Location $location -Name "MyLocalNetworkGateway"
            $name | Should -Be "lgw-mylocalnetworkgateway-dev-uks-bb2f3561"
        }

        It "Should get a VirtualNetworkGateway name" {
            $name = Get-CmAzResourceName -Resource "VirtualNetworkGateway" -Architecture $architecture -Location $location -Name "MyVirtualNetworkGateway"
            $name | Should -Be "vgw-myvirtualnetworkgateway-dev-uks-b4f37153"
        }

        It "Should get a VPNconnection name" {
            $name = Get-CmAzResourceName -Resource "VPNconnection" -Architecture $architecture -Location $location -Name "MyVPNconnection"
            $name | Should -Be "cn-myvpnconnection-239e4329"
        }

        It "Should get a ApplicationGateway name" {
            $name = Get-CmAzResourceName -Resource "ApplicationGateway" -Architecture $architecture -Location $location -Name "MyApplicationGateway"
            $name | Should -Be "agw-myapplicationgateway-dev-uks-c9ff6d91"
        }

        It "Should get a RouteTable name" {
            $name = Get-CmAzResourceName -Resource "RouteTable" -Architecture $architecture -Location $location -Name "MyRouteTable"
            $name | Should -Be "route-myroutetable"
        }

        It "Should get a TrafficManagerProfile name" {
            $name = Get-CmAzResourceName -Resource "TrafficManagerProfile" -Architecture $architecture -Location $location -Name "MyTrafficManagerProfile"
            $name | Should -Be "traf-mytrafficmanagerprofile-dev-uks-9c6018a6"
        }

        It "Should get a Disk name" {
            $name = Get-CmAzResourceName -Resource "Disk" -Architecture $architecture -Location $location -Name "MyDisk"
            $name | Should -Be "dsk-mydisk-dev-uks-a64de35f"
        }

        It "Should get a AvailabilitySet name" {
            $name = Get-CmAzResourceName -Resource "AvailabilitySet" -Architecture $architecture -Location $location -Name "MyAvailabilitySet"
            $name | Should -Be "avail-myavailabilityset-dev-uks-51d447bb"
        }

        It "Should get a VMStorageAccount name" {
            $name = Get-CmAzResourceName -Resource "VMStorageAccount" -Architecture $architecture -Location $location -Name "MyVMStorageAccount"
            $name | Should -Be "stvmmyvmstorageaccounte4c228da"
        }

        It "Should get a AzureArcconnectedmachine name" {
            $name = Get-CmAzResourceName -Resource "AzureArcconnectedmachine" -Architecture $architecture -Location $location -Name "MyAzureArcconnectedmachine"
            $name | Should -Be "arcm-myazurearcconnectedmachine-dev-uks-296f1488"
        }

        It "Should get a ContainerInstance name" {
            $name = Get-CmAzResourceName -Resource "ContainerInstance" -Architecture $architecture -Location $location -Name "MyContainerInstance"
            $name | Should -Be "aci-mycontainerinstance-dev-uks-154a81a7"
        }

        It "Should get a AKSCluster name" {
            $name = Get-CmAzResourceName -Resource "AKSCluster" -Architecture $architecture -Location $location -Name "MyAKSCluster"
            $name | Should -Be "aks-myakscluster-dev-uks-6cdf81bd"
        }

        It "Should get a ServiceFabricCluster name" {
            $name = Get-CmAzResourceName -Resource "ServiceFabricCluster" -Architecture $architecture -Location $location -Name "MyServiceFabricCluster"
            $name | Should -Be "sf-myservicefabriccluster-dev-uks-1a3bab9f"
        }

        It "Should get a AppServiceEnvironment name" {
            $name = Get-CmAzResourceName -Resource "AppServiceEnvironment" -Architecture $architecture -Location $location -Name "MyAppServiceEnvironment"
            $name | Should -Be "ase-myappserviceenvironment-dev-uks-1d57e19d"
        }

        It "Should get a AppServicePlan name" {
            $name = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture $architecture -Location $location -Name "MyAppServicePlan"
            $name | Should -Be "plan-myappserviceplan-dev-uks-efffb94e"
        }

        It "Should get a WebApp name" {
            $name = Get-CmAzResourceName -Resource "WebApp" -Architecture $architecture -Location $location -Name "MyWebApp" -IncludeBuild
            $name | Should -Be "app-mywebapp-dev-909260e2-001"
        }

        It "Should get a FunctionApp name" {
            $name = Get-CmAzResourceName -Resource "FunctionApp" -Architecture $architecture -Location $location -Name "MyFunctionApp" -IncludeBuild
            $name | Should -Be "func-myfunctionapp-dev-4f6634ae-001"
        }

        It "Should get a CloudService name" {
            $name = Get-CmAzResourceName -Resource "CloudService" -Architecture $architecture -Location $location -Name "MyCloudService" -IncludeBuild
            $name | Should -Be "cld-mycloudservice-dev-71a7c051-001"
        }

        It "Should get a NotificationHubs name" {
            $name = Get-CmAzResourceName -Resource "NotificationHubs" -Architecture $architecture -Location $location -Name "MyNotificationHubs"
            $name | Should -Be "ntf-mynotificationhubs-dev"
        }

        It "Should get a NotificationHubsnamespace name" {
            $name = Get-CmAzResourceName -Resource "NotificationHubsnamespace" -Architecture $architecture -Location $location -Name "MyNotificationHubsnamespace"
            $name | Should -Be "ntfns-mynotificationhubsnamespace-dev"
        }

        It "Should get a AzureSQLDatabaseserver name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDatabaseserver" -Architecture $architecture -Location $location -Name "MyAzureSQLDatabaseserver"
            $name | Should -Be "sql-myazuresqldatabaseserver-dev"
        }

        It "Should get a AzureSQLDatabase name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDatabase" -Architecture $architecture -Location $location -Name "MyAzureSQLDatabase"
            $name | Should -Be "sqldb-myazuresqldatabase-dev"
        }

        It "Should get a AzureCosmosDBdatabase name" {
            $name = Get-CmAzResourceName -Resource "AzureCosmosDBdatabase" -Architecture $architecture -Location $location -Name "MyAzureCosmosDBdatabase"
            $name | Should -Be "cosmos-myazurecosmosdbdatabase-dev"
        }

        It "Should get a AzureCacheforRedisinstance name" {
            $name = Get-CmAzResourceName -Resource "AzureCacheforRedisinstance" -Architecture $architecture -Location $location -Name "MyAzureCacheforRedisinstance"
            $name | Should -Be "redis-myazurecacheforredisinstance-dev"
        }

        It "Should get a MySQLdatabase name" {
            $name = Get-CmAzResourceName -Resource "MySQLdatabase" -Architecture $architecture -Location $location -Name "MyMySQLdatabase"
            $name | Should -Be "mysql-mymysqldatabase-dev"
        }

        It "Should get a PostgreSQLdatabase name" {
            $name = Get-CmAzResourceName -Resource "PostgreSQLdatabase" -Architecture $architecture -Location $location -Name "MyPostgreSQLdatabase"
            $name | Should -Be "psql-mypostgresqldatabase-dev"
        }

        It "Should get a AzureSQLDataWarehouse name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDataWarehouse" -Architecture $architecture -Location $location -Name "MyAzureSQLDataWarehouse"
            $name | Should -Be "sqldw-myazuresqldatawarehouse-dev"
        }

        It "Should get a AzureSynapseAnalytics name" {
            $name = Get-CmAzResourceName -Resource "AzureSynapseAnalytics" -Architecture $architecture -Location $location -Name "MyAzureSynapseAnalytics"
            $name | Should -Be "syn-myazuresynapseanalytics-dev-uks-4199a6bf"
        }

        It "Should get a SQLServerStretchDatabase name" {
            $name = Get-CmAzResourceName -Resource "SQLServerStretchDatabase" -Architecture $architecture -Location $location -Name "MySQLServerStretchDatabase"
            $name | Should -Be "sqlstrdb-mysqlserverstretchdatabase-dev"
        }

        It "Should get a Storageaccount name" {
            $name = Get-CmAzResourceName -Resource "Storageaccount" -Architecture $architecture -Location $location -Name "MyStorageaccount"
            $name | Should -Be "stmystorageaccountbd0fa5"
        }

        It "Should get a AzureStorSimple name" {
            $name = Get-CmAzResourceName -Resource "AzureStorSimple" -Architecture $architecture -Location $location -Name "MyAzureStorSimple"
            $name | Should -Be "ssimpmyazurestorsimple03523493"
        }

        It "Should get a AzureCognitiveSearch name" {
            $name = Get-CmAzResourceName -Resource "AzureCognitiveSearch" -Architecture $architecture -Location $location -Name "MyAzureCognitiveSearch"
            $name | Should -Be "srch-myazurecognitivesearch-dev"
        }

        It "Should get a AzureCognitiveServices name" {
            $name = Get-CmAzResourceName -Resource "AzureCognitiveServices" -Architecture $architecture -Location $location -Name "MyAzureCognitiveServices"
            $name | Should -Be "cog-myazurecognitiveservices-dev"
        }

        It "Should get a AzureMachineLearningworkspace name" {
            $name = Get-CmAzResourceName -Resource "AzureMachineLearningworkspace" -Architecture $architecture -Location $location -Name "MyAzureMachineLearningworkspace"
            $name | Should -Be "mlw-myazuremachinelearningworkspace-dev"
        }

        It "Should get a AzureAnalysisServicesserver name" {
            $name = Get-CmAzResourceName -Resource "AzureAnalysisServicesserver" -Architecture $architecture -Location $location -Name "MyAzureAnalysisServicesserver"
            $name | Should -Be "as-myazureanalysisservicesserver-dev"
        }

        It "Should get a AzureDatabricksworkspace name" {
            $name = Get-CmAzResourceName -Resource "AzureDatabricksworkspace" -Architecture $architecture -Location $location -Name "MyAzureDatabricksworkspace"
            $name | Should -Be "dbw-myazuredatabricksworkspace-dev"
        }

        It "Should get a AzureStreamAnalytics name" {
            $name = Get-CmAzResourceName -Resource "AzureStreamAnalytics" -Architecture $architecture -Location $location -Name "MyAzureStreamAnalytics"
            $name | Should -Be "asa-myazurestreamanalytics-dev"
        }

        It "Should get a AzureDataFactory name" {
            $name = Get-CmAzResourceName -Resource "AzureDataFactory" -Architecture $architecture -Location $location -Name "MyAzureDataFactory"
            $name | Should -Be "adf-myazuredatafactory-dev"
        }

        It "Should get a DataLakeStoreaccount name" {
            $name = Get-CmAzResourceName -Resource "DataLakeStoreaccount" -Architecture $architecture -Location $location -Name "MyDataLakeStoreaccount"
            $name | Should -Be "dls-mydatalakestoreaccount-dev"
        }

        It "Should get a DataLakeAnalyticsaccount name" {
            $name = Get-CmAzResourceName -Resource "DataLakeAnalyticsaccount" -Architecture $architecture -Location $location -Name "MyDataLakeAnalyticsaccount"
            $name | Should -Be "dla-mydatalakeanalyticsaccount-dev"
        }

        It "Should get a Eventhub name" {
            $name = Get-CmAzResourceName -Resource "Eventhub" -Architecture $architecture -Location $location -Name "MyEventhub"
            $name | Should -Be "evh-myeventhub-dev"
        }

        It "Should get a HDInsightHadoopcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightHadoopcluster" -Architecture $architecture -Location $location -Name "MyHDInsightHadoopcluster"
            $name | Should -Be "hadoop-myhdinsighthadoopcluster-dev"
        }

        It "Should get a HDInsightHBasecluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightHBasecluster" -Architecture $architecture -Location $location -Name "MyHDInsightHBasecluster"
            $name | Should -Be "hbase-myhdinsighthbasecluster-dev"
        }

        It "Should get a HDInsightKafkacluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightKafkacluster" -Architecture $architecture -Location $location -Name "MyHDInsightKafkacluster"
            $name | Should -Be "kafka-myhdinsightkafkacluster-dev"
        }

        It "Should get a HDInsightSparkcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightSparkcluster" -Architecture $architecture -Location $location -Name "MyHDInsightSparkcluster"
            $name | Should -Be "spark-myhdinsightsparkcluster-dev"
        }

        It "Should get a HDInsightStormcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightStormcluster" -Architecture $architecture -Location $location -Name "MyHDInsightStormcluster"
            $name | Should -Be "storm-myhdinsightstormcluster-dev"
        }

        It "Should get a HDInsightMLServicescluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightMLServicescluster" -Architecture $architecture -Location $location -Name "MyHDInsightMLServicescluster"
            $name | Should -Be "mls-myhdinsightmlservicescluster-dev"
        }

        It "Should get a IoThub name" {
            $name = Get-CmAzResourceName -Resource "IoThub" -Architecture $architecture -Location $location -Name "MyIoThub"
            $name | Should -Be "iot-myiothub-dev"
        }

        It "Should get a PowerBIEmbedded name" {
            $name = Get-CmAzResourceName -Resource "PowerBIEmbedded" -Architecture $architecture -Location $location -Name "MyPowerBIEmbedded"
            $name | Should -Be "pbi-mypowerbiembedded-dev"
        }

        It "Should get a LogicApps name" {
            $name = Get-CmAzResourceName -Resource "LogicApps" -Architecture $architecture -Location $location -Name "MyLogicApps"
            $name | Should -Be "logic-mylogicapps-dev"
        }

        It "Should get a ServiceBus name" {
            $name = Get-CmAzResourceName -Resource "ServiceBus" -Architecture $architecture -Location $location -Name "MyServiceBus"
            $name | Should -Be "sb-myservicebus-dev"
        }

        It "Should get a ServiceBusQueue name" {
            $name = Get-CmAzResourceName -Resource "ServiceBusQueue" -Architecture $architecture -Location $location -Name "MyServiceBusQueue"
            $name | Should -Be "sbq-myservicebusqueue-dev"
        }

        It "Should get a ServiceBusTopic name" {
            $name = Get-CmAzResourceName -Resource "ServiceBusTopic" -Architecture $architecture -Location $location -Name "MyServiceBusTopic"
            $name | Should -Be "sbt-myservicebustopic-dev"
        }

        It "Should get a Blueprint name" {
            $name = Get-CmAzResourceName -Resource "Blueprint" -Architecture $architecture -Location $location -Name "MyBlueprint"
            $name | Should -Be "bp-myblueprint-dev-uks-8dc25957"
        }

        It "Should get a Keyvault name" {
            $name = Get-CmAzResourceName -Resource "Keyvault" -Architecture $architecture -Location $location -Name "MyKeyvault"
            $name | Should -Be "kv-mykeyvault-uks-d512e232"
        }
        It "Should get a LogAnalyticsworkspace name" {
            $name = Get-CmAzResourceName -Resource "LogAnalyticsworkspace" -Architecture $architecture -Location $location -Name "MyLogAnalyticsworkspace"
            $name | Should -Be "log-myloganalyticsworkspace-dev-uks-03c8a08c"
        }

        It "Should get a ApplicationInsights name" {
            $name = Get-CmAzResourceName -Resource "ApplicationInsights" -Architecture $architecture -Location $location -Name "MyApplicationInsights"
            $name | Should -Be "appi-myapplicationinsights-dev-uks-82f34eb7"
        }

        It "Should get a RecoveryServicesvault name" {
            $name = Get-CmAzResourceName -Resource "RecoveryServicesvault" -Architecture $architecture -Location $location -Name "MyRecoveryServicesvault"
            $name | Should -Be "rsv-myrecoveryservicesvault-dev-uks-40f2e103"
        }

        It "Should get a AzureMigrateproject name" {
            $name = Get-CmAzResourceName -Resource "AzureMigrateproject" -Architecture $architecture -Location $location -Name "MyAzureMigrateproject"
            $name | Should -Be "migr-myazuremigrateproject-dev-uks-e02e0d51"
        }

        It "Should get a DatabaseMigrationServiceinstance name" {
            $name = Get-CmAzResourceName -Resource "DatabaseMigrationServiceinstance" -Architecture $architecture -Location $location -Name "MyDatabaseMigrationServiceinstance"
            $name | Should -Be "dms-mydatabasemigrationserviceinstance-dev-uks-f4a56712"
        }

        It "Should get a OSDisk name" {
            $name = Get-CmAzResourceName -Resource "OSDisk" -Architecture $architecture -Location $location -Name "MyOSDisk"
            $name | Should -Be "osdk-myosdisk-dev-uks-6823383f"
        }

        It "Should get a DataDisk name" {
            $name = Get-CmAzResourceName -Resource "DataDisk" -Architecture $architecture -Location $location -Name "MyDataDisk"
            $name | Should -Be "ddk-mydatadisk-dev-uks-1e584fe6"
        }

        It "Should get a ComputerName name" {
            $name = Get-CmAzResourceName -Resource "ComputerName" -Architecture $architecture -Location $location -Name "MyComputerName"
            $name | Should -Be "compmycomputernameb4acd664"
        }

        It "Should get a Automation name" {
            $name = Get-CmAzResourceName -Resource "Automation" -Architecture $architecture -Location $location -Name "MyAutomation"
            $name | Should -Be "auto-myautomation-dev-uks-31397c98"
        }

        It "Should get a CdnProfile name" {
            $name = Get-CmAzResourceName -Resource "CdnProfile" -Architecture $architecture -Location $location -Name "MyCdnProfile"
            $name | Should -Be "cdn-mycdnprofile-dev-uks-f6e7916a"
        }
        It "Should get a ActionGroup name" {
            $name = Get-CmAzResourceName -Resource "ActionGroup" -Architecture $architecture -Location $location -Name "MyActionGroup"
            $name | Should -Be "agrp-myactiongroup-dev-uks-b5b8d0c1"
        }

        It "Should get a ActionGroupReceiver name" {
            $name = Get-CmAzResourceName -Resource "ActionGroupReceiver" -Architecture $architecture -Location $location -Name "MyActionGroupReceiver"
            $name | Should -Be "agrprec-myactiongroupreceiver-dev-uks-e01519e8"
        }

        It "Should get a FrontDoor name" {
            $name = Get-CmAzResourceName -Resource "FrontDoor" -Architecture $architecture -Location $location -Name "MyFrontDoor"
            $name | Should -Be "fd-myfrontdoor-dev-uks-27fe25ca"
        }

        It "Should get a Alert name" {
            $name = Get-CmAzResourceName -Resource "Alert" -Architecture $architecture -Location $location -Name "MyServiceHealthAlert"
            $name | Should -Be "alt-myservicehealthalert-dev-uks-a87811a2"
        }

        It "Should get a BastionHost name" {
            $name = Get-CmAzResourceName -Resource "BastionHost" -Architecture $architecture -Location $location -Name "MyBastionHost"
            $name | Should -Be "bastion-mybastionhost-dev-uks-3f2784a4"
        }

        It "Should get a Endpoint name" {
            $name = Get-CmAzResourceName -Resource "Endpoint" -Architecture $architecture -Location $location -Name "MyEndpoint"
            $name | Should -Be "ep-myendpoint-dev-uks-25d99962"
        }
    }
}