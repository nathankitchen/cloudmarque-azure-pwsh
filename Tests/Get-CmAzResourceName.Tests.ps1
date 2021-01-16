. $PSScriptRoot\Initialise-CmAzModule.ps1

Describe "Get-CmAzResourceName" {

    BeforeAll {
        $projectRoot = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project"
        $region = "UK South"
        $architecture = "Core"
    }

    Context "No context has been set" {

        BeforeAll {
            Clear-CmAzContext
        }

        It "Should fail when no CmAzContext has been set" {
            {
                Get-CmAzResourceName -Resource "ResourceGroup" -Architecture $architecture -Region $region -Name "Keys"
            } | Should -Throw "No Cloudmarque Azure context is in place, please run Set-CmAzContext before running this command."
        }
    }

    Context "Assert resources are named correctly" {

        BeforeAll {
            Set-CmAzContext -Environment "Development" -ProjectRoot $projectRoot
        }

        It "Should not have double separators" {
            $name = Get-CmAzResourceName -Resource "Sample2" -Architecture $architecture -Region $region -Name "MyApp"
            $name | Should -Be "default-myapp-dev-uks-5c1753d6"
        }

        It "Should not have seperator before domain name" {
            $name = Get-CmAzResourceName -Resource "WebApp" -Architecture $architecture -Region $region -Name "MyWebApp"
            $name | Should -Not -Contain "-.azurewebsites.net"
        }

        It "Should not have name length greater then defined" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture $architecture -Region $region -Name "MyWindows"
            $name.length | Should -Not -BeGreaterThan 15
        }
    }

    Context "Should report bad parameters" {

        It "Should warn about regions that don't exist" {
            {
                Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "IaaS" -Region "Timbuktoo" -Name "MyApp"
            } | Should -Throw "No regional naming convention found in _names\regions.yml for 'Timbuktoo'"
        }

        It "Should fail when using generators that don't exist" {
            {
                Get-CmAzResourceName -Resource "Sample1" -Architecture "IaaS" -Region "Timbuktoo" -Name "MyApp"
            } | Should -Throw "No regional naming convention found in _names\regions.yml for 'Timbuktoo'"
        }

        It "Should tolerate incorrectly cased resources" {
            $name = Get-CmAzResourceName -Resource "resourceGroup" -Architecture $architecture -Region $region -Name "Keys"
            $name | Should -Be "rg-keys-core-cebe9fa3"
        }
    }
    Context "Getting correct build ID operations" {

        It "Should append build ID" {
            $name = Get-CmAzResourceName -Resource "Budget" -Architecture $architecture -Region $region -Name "MyBudget" -IncludeBuild
            $name | Should -Be "bud-mybudget-dev-uks-bbef0c49-001"
        }

        It "Should get a VirtualMachine name with build ID" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture $architecture -Region $region -Name "MyWindows" -IncludeBuild
            $name | Should -Be "vmmywindows001"
        }
    }

    Context "Get names from the script" {

        It "Should get a ResourceGroup name" {
            $name = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture $architecture -Region $region -Name "MyResourceGroup"
            $name | Should -Be "rg-myresourcegroup-core-b3760842"
        }

        It "Should get a VirtualMachine name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture $architecture -Region $region -Name "MyWindows"
            $name | Should -Be "vmmywindowsa941"
        }

        It "Should get a VirtualMachineLinux name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineLinux" -Architecture $architecture -Region $region -Name "MyVirtualMachineLinux"
            $name | Should -Be "vmmyvirtualmachinelinux78361ba6"
        }

        It "Should get a VirtualMachineScaleset name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineScaleset" -Architecture $architecture -Region $region -Name "Scaleset"
            $name | Should -Be "vmssscalesetc29"
        }

        It "Should get a VirtualMachineScalesetLinux name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineScalesetLinux" -Architecture $architecture -Region $region -Name "MyVirtualMachineScalesetLinux"
            $name | Should -Be "vmssmyvirtualmachinescalesetlinux7785511e"
        }

        It "Should get a PolicyDefinition name" {
            $name = Get-CmAzResourceName -Resource "PolicyDefinition" -Architecture $architecture -Region $region -Name "MyPolicyDefinition"
            $name | Should -Be "policy-mypolicydefinition-dev-uks-c01ca77c"
        }

        It "Should get a APImanagementServiceInstance name" {
            $name = Get-CmAzResourceName -Resource "APImanagementServiceInstance" -Architecture $architecture -Region $region -Name "MyAPImanagementServiceInstance"
            $name | Should -Be "apim-myapimanagementserviceinstance-dev-uks-5adcdcab"
        }

        It "Should get a VirtualNetwork name" {
            $name = Get-CmAzResourceName -Resource "VirtualNetwork" -Architecture $architecture -Region $region -Name "MyVirtualNetwork"
            $name | Should -Be "vnet-myvirtualnetwork-dev-uks-df5dee74"
        }

        It "Should get a Subnet name" {
            $name = Get-CmAzResourceName -Resource "Subnet" -Architecture $architecture -Region $region -Name "MySubnet"
            $name | Should -Be "snet-mysubnet-dev-uks-52524038"
        }

        It "Should get a Budget name" {
            $name = Get-CmAzResourceName -Resource "Budget" -Architecture $architecture -Region $region -Name "MyBudget"
            $name | Should -Be "bud-mybudget-dev-uks-bbef0c49"
        }

        It "Should get a AutomationSchedule name" {
            $name = Get-CmAzResourceName -Resource "AutomationSchedule" -Architecture $architecture -Region $region -Name "MyAutomationSchedule"
            $name | Should -Be "atshed-myautomationschedule-dev-uks-13fe9332"
        }

        It "Should get a NetworkInterfaceCard name" {
            $name = Get-CmAzResourceName -Resource "NetworkInterfaceCard" -Architecture $architecture -Region $region -Name "MyNetworkInterfaceCard"
            $name | Should -Be "nic-mynetworkinterfacecard-dev-uks-d3a7f144"
        }

        It "Should get a PublicIPAddress name" {
            $name = Get-CmAzResourceName -Resource "PublicIPAddress" -Architecture $architecture -Region $region -Name "MyPublicIPAddress"
            $name | Should -Be "pip-mypublicipaddress-dev-uks-db600510"
        }

        It "Should get a LoadbalancerInternal name" {
            $name = Get-CmAzResourceName -Resource "LoadbalancerInternal" -Architecture $architecture -Region $region -Name "MyLoadbalancerInternal"
            $name | Should -Be "lbi-myloadbalancerinternal-dev-uks-5dba7d4b"
        }

        It "Should get a LoadbalancerExternal name" {
            $name = Get-CmAzResourceName -Resource "LoadbalancerExternal" -Architecture $architecture -Region $region -Name "MyLoadbalancerExternal"
            $name | Should -Be "lbe-myloadbalancerexternal-dev-uks-6a9269b3"
        }

        It "Should get a NetworkSecurityGroup name" {
            $name = Get-CmAzResourceName -Resource "NetworkSecurityGroup" -Architecture $architecture -Region $region -Name "MyNetworkSecurityGroup"
            $name | Should -Be "nsg-mynetworksecuritygroup-e856f8dd"
        }

        It "Should get a ApplicationSecurityGroup name" {
            $name = Get-CmAzResourceName -Resource "ApplicationSecurityGroup" -Architecture $architecture -Region $region -Name "MyApplicationSecurityGroup"
            $name | Should -Be "asg-myapplicationsecuritygroup-dev-uks-fa2ec1a4"
        }

        It "Should get a LocalNetworkGateway name" {
            $name = Get-CmAzResourceName -Resource "LocalNetworkGateway" -Architecture $architecture -Region $region -Name "MyLocalNetworkGateway"
            $name | Should -Be "lgw-mylocalnetworkgateway-dev-uks-bb2f3561"
        }

        It "Should get a VirtualNetworkGateway name" {
            $name = Get-CmAzResourceName -Resource "VirtualNetworkGateway" -Architecture $architecture -Region $region -Name "MyVirtualNetworkGateway"
            $name | Should -Be "vgw-myvirtualnetworkgateway-dev-uks-b4f37153"
        }

        It "Should get a VPNconnection name" {
            $name = Get-CmAzResourceName -Resource "VPNconnection" -Architecture $architecture -Region $region -Name "MyVPNconnection"
            $name | Should -Be "cn-myvpnconnection-239e4329"
        }

        It "Should get a ApplicationGateway name" {
            $name = Get-CmAzResourceName -Resource "ApplicationGateway" -Architecture $architecture -Region $region -Name "MyApplicationGateway"
            $name | Should -Be "agw-myapplicationgateway-dev-uks-c9ff6d91"
        }

        It "Should get a RouteTable name" {
            $name = Get-CmAzResourceName -Resource "RouteTable" -Architecture $architecture -Region $region -Name "MyRouteTable"
            $name | Should -Be "route-myroutetable"
        }

        It "Should get a TrafficManagerProfile name" {
            $name = Get-CmAzResourceName -Resource "TrafficManagerProfile" -Architecture $architecture -Region $region -Name "MyTrafficManagerProfile"
            $name | Should -Be "traf-mytrafficmanagerprofile-dev-uks-9c6018a6"
        }

        It "Should get a Disk name" {
            $name = Get-CmAzResourceName -Resource "Disk" -Architecture $architecture -Region $region -Name "MyDisk"
            $name | Should -Be "dsk-mydisk-dev-uks-a64de35f"
        }

        It "Should get a AvailabilitySet name" {
            $name = Get-CmAzResourceName -Resource "AvailabilitySet" -Architecture $architecture -Region $region -Name "MyAvailabilitySet"
            $name | Should -Be "avail-myavailabilityset-dev-uks-51d447bb"
        }

        It "Should get a VMStorageAccount name" {
            $name = Get-CmAzResourceName -Resource "VMStorageAccount" -Architecture $architecture -Region $region -Name "MyVMStorageAccount"
            $name | Should -Be "stvmmyvmstorageaccounte4c228da"
        }

        It "Should get a AzureArcconnectedmachine name" {
            $name = Get-CmAzResourceName -Resource "AzureArcconnectedmachine" -Architecture $architecture -Region $region -Name "MyAzureArcconnectedmachine"
            $name | Should -Be "arcm-myazurearcconnectedmachine-dev-uks-296f1488"
        }

        It "Should get a ContainerInstance name" {
            $name = Get-CmAzResourceName -Resource "ContainerInstance" -Architecture $architecture -Region $region -Name "MyContainerInstance"
            $name | Should -Be "aci-mycontainerinstance-dev-uks-154a81a7"
        }

        It "Should get a AKSCluster name" {
            $name = Get-CmAzResourceName -Resource "AKSCluster" -Architecture $architecture -Region $region -Name "MyAKSCluster"
            $name | Should -Be "aks-myakscluster-dev-uks-6cdf81bd"
        }

        It "Should get a ServiceFabricCluster name" {
            $name = Get-CmAzResourceName -Resource "ServiceFabricCluster" -Architecture $architecture -Region $region -Name "MyServiceFabricCluster"
            $name | Should -Be "sf-myservicefabriccluster-dev-uks-1a3bab9f"
        }

        It "Should get a AppServiceEnvironment name" {
            $name = Get-CmAzResourceName -Resource "AppServiceEnvironment" -Architecture $architecture -Region $region -Name "MyAppServiceEnvironment"
            $name | Should -Be "ase-myappserviceenvironment-dev-uks-1d57e19d"
        }

        It "Should get a AppServicePlan name" {
            $name = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture $architecture -Region $region -Name "MyAppServicePlan"
            $name | Should -Be "plan-myappserviceplan-dev-uks-efffb94e"
        }

        It "Should get a WebApp name" {
            $name = Get-CmAzResourceName -Resource "WebApp" -Architecture $architecture -Region $region -Name "MyWebApp" -IncludeBuild
            $name | Should -Be "app-mywebapp-dev-909260e2-001"
        }

        It "Should get a FunctionApp name" {
            $name = Get-CmAzResourceName -Resource "FunctionApp" -Architecture $architecture -Region $region -Name "MyFunctionApp" -IncludeBuild
            $name | Should -Be "func-myfunctionapp-dev-4f6634ae-001"
        }

        It "Should get a CloudService name" {
            $name = Get-CmAzResourceName -Resource "CloudService" -Architecture $architecture -Region $region -Name "MyCloudService" -IncludeBuild
            $name | Should -Be "cld-mycloudservice-dev-71a7c051-001"
        }

        It "Should get a NotificationHubs name" {
            $name = Get-CmAzResourceName -Resource "NotificationHubs" -Architecture $architecture -Region $region -Name "MyNotificationHubs"
            $name | Should -Be "ntf-mynotificationhubs-dev"
        }

        It "Should get a NotificationHubsnamespace name" {
            $name = Get-CmAzResourceName -Resource "NotificationHubsnamespace" -Architecture $architecture -Region $region -Name "MyNotificationHubsnamespace"
            $name | Should -Be "ntfns-mynotificationhubsnamespace-dev"
        }

        It "Should get a AzureSQLDatabaseserver name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDatabaseserver" -Architecture $architecture -Region $region -Name "MyAzureSQLDatabaseserver"
            $name | Should -Be "sql-myazuresqldatabaseserver-dev"
        }

        It "Should get a AzureSQLDatabase name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDatabase" -Architecture $architecture -Region $region -Name "MyAzureSQLDatabase"
            $name | Should -Be "sqldb-myazuresqldatabase-dev"
        }

        It "Should get a AzureCosmosDBdatabase name" {
            $name = Get-CmAzResourceName -Resource "AzureCosmosDBdatabase" -Architecture $architecture -Region $region -Name "MyAzureCosmosDBdatabase"
            $name | Should -Be "cosmos-myazurecosmosdbdatabase-dev"
        }

        It "Should get a AzureCacheforRedisinstance name" {
            $name = Get-CmAzResourceName -Resource "AzureCacheforRedisinstance" -Architecture $architecture -Region $region -Name "MyAzureCacheforRedisinstance"
            $name | Should -Be "redis-myazurecacheforredisinstance-dev"
        }

        It "Should get a MySQLdatabase name" {
            $name = Get-CmAzResourceName -Resource "MySQLdatabase" -Architecture $architecture -Region $region -Name "MyMySQLdatabase"
            $name | Should -Be "mysql-mymysqldatabase-dev"
        }

        It "Should get a PostgreSQLdatabase name" {
            $name = Get-CmAzResourceName -Resource "PostgreSQLdatabase" -Architecture $architecture -Region $region -Name "MyPostgreSQLdatabase"
            $name | Should -Be "psql-mypostgresqldatabase-dev"
        }

        It "Should get a AzureSQLDataWarehouse name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDataWarehouse" -Architecture $architecture -Region $region -Name "MyAzureSQLDataWarehouse"
            $name | Should -Be "sqldw-myazuresqldatawarehouse-dev"
        }

        It "Should get a AzureSynapseAnalytics name" {
            $name = Get-CmAzResourceName -Resource "AzureSynapseAnalytics" -Architecture $architecture -Region $region -Name "MyAzureSynapseAnalytics"
            $name | Should -Be "syn-myazuresynapseanalytics-dev-uks-4199a6bf"
        }

        It "Should get a SQLServerStretchDatabase name" {
            $name = Get-CmAzResourceName -Resource "SQLServerStretchDatabase" -Architecture $architecture -Region $region -Name "MySQLServerStretchDatabase"
            $name | Should -Be "sqlstrdb-mysqlserverstretchdatabase-dev"
        }

        It "Should get a Storageaccount name" {
            $name = Get-CmAzResourceName -Resource "Storageaccount" -Architecture $architecture -Region $region -Name "MyStorageaccount"
            $name | Should -Be "stmystorageaccountbd0fa5"
        }

        It "Should get a AzureStorSimple name" {
            $name = Get-CmAzResourceName -Resource "AzureStorSimple" -Architecture $architecture -Region $region -Name "MyAzureStorSimple"
            $name | Should -Be "ssimpmyazurestorsimple03523493"
        }

        It "Should get a AzureCognitiveSearch name" {
            $name = Get-CmAzResourceName -Resource "AzureCognitiveSearch" -Architecture $architecture -Region $region -Name "MyAzureCognitiveSearch"
            $name | Should -Be "srch-myazurecognitivesearch-dev"
        }

        It "Should get a AzureCognitiveServices name" {
            $name = Get-CmAzResourceName -Resource "AzureCognitiveServices" -Architecture $architecture -Region $region -Name "MyAzureCognitiveServices"
            $name | Should -Be "cog-myazurecognitiveservices-dev"
        }

        It "Should get a AzureMachineLearningworkspace name" {
            $name = Get-CmAzResourceName -Resource "AzureMachineLearningworkspace" -Architecture $architecture -Region $region -Name "MyAzureMachineLearningworkspace"
            $name | Should -Be "mlw-myazuremachinelearningworkspace-dev"
        }

        It "Should get a AzureAnalysisServicesserver name" {
            $name = Get-CmAzResourceName -Resource "AzureAnalysisServicesserver" -Architecture $architecture -Region $region -Name "MyAzureAnalysisServicesserver"
            $name | Should -Be "as-myazureanalysisservicesserver-dev"
        }

        It "Should get a AzureDatabricksworkspace name" {
            $name = Get-CmAzResourceName -Resource "AzureDatabricksworkspace" -Architecture $architecture -Region $region -Name "MyAzureDatabricksworkspace"
            $name | Should -Be "dbw-myazuredatabricksworkspace-dev"
        }

        It "Should get a AzureStreamAnalytics name" {
            $name = Get-CmAzResourceName -Resource "AzureStreamAnalytics" -Architecture $architecture -Region $region -Name "MyAzureStreamAnalytics"
            $name | Should -Be "asa-myazurestreamanalytics-dev"
        }

        It "Should get a AzureDataFactory name" {
            $name = Get-CmAzResourceName -Resource "AzureDataFactory" -Architecture $architecture -Region $region -Name "MyAzureDataFactory"
            $name | Should -Be "adf-myazuredatafactory-dev"
        }

        It "Should get a DataLakeStoreaccount name" {
            $name = Get-CmAzResourceName -Resource "DataLakeStoreaccount" -Architecture $architecture -Region $region -Name "MyDataLakeStoreaccount"
            $name | Should -Be "dls-mydatalakestoreaccount-dev"
        }

        It "Should get a DataLakeAnalyticsaccount name" {
            $name = Get-CmAzResourceName -Resource "DataLakeAnalyticsaccount" -Architecture $architecture -Region $region -Name "MyDataLakeAnalyticsaccount"
            $name | Should -Be "dla-mydatalakeanalyticsaccount-dev"
        }

        It "Should get a Eventhub name" {
            $name = Get-CmAzResourceName -Resource "Eventhub" -Architecture $architecture -Region $region -Name "MyEventhub"
            $name | Should -Be "evh-myeventhub-dev"
        }

        It "Should get a HDInsightHadoopcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightHadoopcluster" -Architecture $architecture -Region $region -Name "MyHDInsightHadoopcluster"
            $name | Should -Be "hadoop-myhdinsighthadoopcluster-dev"
        }

        It "Should get a HDInsightHBasecluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightHBasecluster" -Architecture $architecture -Region $region -Name "MyHDInsightHBasecluster"
            $name | Should -Be "hbase-myhdinsighthbasecluster-dev"
        }

        It "Should get a HDInsightKafkacluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightKafkacluster" -Architecture $architecture -Region $region -Name "MyHDInsightKafkacluster"
            $name | Should -Be "kafka-myhdinsightkafkacluster-dev"
        }

        It "Should get a HDInsightSparkcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightSparkcluster" -Architecture $architecture -Region $region -Name "MyHDInsightSparkcluster"
            $name | Should -Be "spark-myhdinsightsparkcluster-dev"
        }

        It "Should get a HDInsightStormcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightStormcluster" -Architecture $architecture -Region $region -Name "MyHDInsightStormcluster"
            $name | Should -Be "storm-myhdinsightstormcluster-dev"
        }

        It "Should get a HDInsightMLServicescluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightMLServicescluster" -Architecture $architecture -Region $region -Name "MyHDInsightMLServicescluster"
            $name | Should -Be "mls-myhdinsightmlservicescluster-dev"
        }

        It "Should get a IoThub name" {
            $name = Get-CmAzResourceName -Resource "IoThub" -Architecture $architecture -Region $region -Name "MyIoThub"
            $name | Should -Be "iot-myiothub-dev"
        }

        It "Should get a PowerBIEmbedded name" {
            $name = Get-CmAzResourceName -Resource "PowerBIEmbedded" -Architecture $architecture -Region $region -Name "MyPowerBIEmbedded"
            $name | Should -Be "pbi-mypowerbiembedded-dev"
        }

        It "Should get a LogicApps name" {
            $name = Get-CmAzResourceName -Resource "LogicApps" -Architecture $architecture -Region $region -Name "MyLogicApps"
            $name | Should -Be "logic-mylogicapps-dev"
        }

        It "Should get a ServiceBus name" {
            $name = Get-CmAzResourceName -Resource "ServiceBus" -Architecture $architecture -Region $region -Name "MyServiceBus"
            $name | Should -Be "sb-myservicebus-dev"
        }

        It "Should get a ServiceBusQueue name" {
            $name = Get-CmAzResourceName -Resource "ServiceBusQueue" -Architecture $architecture -Region $region -Name "MyServiceBusQueue"
            $name | Should -Be "sbq-myservicebusqueue-dev"
        }

        It "Should get a ServiceBusTopic name" {
            $name = Get-CmAzResourceName -Resource "ServiceBusTopic" -Architecture $architecture -Region $region -Name "MyServiceBusTopic"
            $name | Should -Be "sbt-myservicebustopic-dev"
        }

        It "Should get a Blueprint name" {
            $name = Get-CmAzResourceName -Resource "Blueprint" -Architecture $architecture -Region $region -Name "MyBlueprint"
            $name | Should -Be "bp-myblueprint-dev-uks-8dc25957"
        }

        It "Should get a Keyvault name" {
            $name = Get-CmAzResourceName -Resource "Keyvault" -Architecture $architecture -Region $region -Name "MyKeyvault"
            $name | Should -Be "kv-mykeyvault-uks-d512e232"
        }
        It "Should get a LogAnalyticsworkspace name" {
            $name = Get-CmAzResourceName -Resource "LogAnalyticsworkspace" -Architecture $architecture -Region $region -Name "MyLogAnalyticsworkspace"
            $name | Should -Be "log-myloganalyticsworkspace-dev-uks-03c8a08c"
        }

        It "Should get a ApplicationInsights name" {
            $name = Get-CmAzResourceName -Resource "ApplicationInsights" -Architecture $architecture -Region $region -Name "MyApplicationInsights"
            $name | Should -Be "appi-myapplicationinsights-dev-uks-82f34eb7"
        }

        It "Should get a RecoveryServicesvault name" {
            $name = Get-CmAzResourceName -Resource "RecoveryServicesvault" -Architecture $architecture -Region $region -Name "MyRecoveryServicesvault"
            $name | Should -Be "rsv-myrecoveryservicesvault-dev-uks-40f2e103"
        }

        It "Should get a AzureMigrateproject name" {
            $name = Get-CmAzResourceName -Resource "AzureMigrateproject" -Architecture $architecture -Region $region -Name "MyAzureMigrateproject"
            $name | Should -Be "migr-myazuremigrateproject-dev-uks-e02e0d51"
        }

        It "Should get a DatabaseMigrationServiceinstance name" {
            $name = Get-CmAzResourceName -Resource "DatabaseMigrationServiceinstance" -Architecture $architecture -Region $region -Name "MyDatabaseMigrationServiceinstance"
            $name | Should -Be "dms-mydatabasemigrationserviceinstance-dev-uks-f4a56712"
        }

        It "Should get a OSDisk name" {
            $name = Get-CmAzResourceName -Resource "OSDisk" -Architecture $architecture -Region $region -Name "MyOSDisk"
            $name | Should -Be "osdk-myosdisk-dev-uks-6823383f"
        }

        It "Should get a DataDisk name" {
            $name = Get-CmAzResourceName -Resource "DataDisk" -Architecture $architecture -Region $region -Name "MyDataDisk"
            $name | Should -Be "ddk-mydatadisk-dev-uks-1e584fe6"
        }

        It "Should get a ComputerName name" {
            $name = Get-CmAzResourceName -Resource "ComputerName" -Architecture $architecture -Region $region -Name "MyComputerName"
            $name | Should -Be "compmycomputernameb4acd664"
        }

        It "Should get a Automation name" {
            $name = Get-CmAzResourceName -Resource "Automation" -Architecture $architecture -Region $region -Name "MyAutomation"
            $name | Should -Be "auto-myautomation-dev-uks-31397c98"
        }

        It "Should get a CdnProfile name" {
            $name = Get-CmAzResourceName -Resource "CdnProfile" -Architecture $architecture -Region $region -Name "MyCdnProfile"
            $name | Should -Be "cdn-mycdnprofile-dev-uks-f6e7916a"
        }
        It "Should get a ActionGroup name" {
            $name = Get-CmAzResourceName -Resource "ActionGroup" -Architecture $architecture -Region $region -Name "MyActionGroup"
            $name | Should -Be "agrp-myactiongroup-dev-uks-b5b8d0c1"
        }

        It "Should get a ActionGroupReceiver name" {
            $name = Get-CmAzResourceName -Resource "ActionGroupReceiver" -Architecture $architecture -Region $region -Name "MyActionGroupReceiver"
            $name | Should -Be "agrprec-myactiongroupreceiver-dev-uks-e01519e8"
        }

        It "Should get a FrontDoor name" {
            $name = Get-CmAzResourceName -Resource "FrontDoor" -Architecture $architecture -Region $region -Name "MyFrontDoor"
            $name | Should -Be "fd-myfrontdoor-dev-uks-27fe25ca"
        }

        It "Should get a Alert name" {
            $name = Get-CmAzResourceName -Resource "Alert" -Architecture $architecture -Region $region -Name "MyServiceHealthAlert"
            $name | Should -Be "alt-myservicehealthalert-dev-uks-a87811a2"
        }

        It "Should get a BastionHost name" {
            $name = Get-CmAzResourceName -Resource "BastionHost" -Architecture $architecture -Region $region -Name "MyBastionHost"
            $name | Should -Be "bastion-mybastionhost-dev-uks-3f2784a4"
        }

        It "Should get a Endpoint name" {
            $name = Get-CmAzResourceName -Resource "Endpoint" -Architecture $architecture -Region $region -Name "MyEndpoint"
            $name | Should -Be "ep-myendpoint-dev-uks-25d99962"
        }
    }
}