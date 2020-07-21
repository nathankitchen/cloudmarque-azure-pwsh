. $PSScriptRoot\Initialise-CmAzModule.ps1

$projectRoot = "$PSScriptRoot\..\Cloudmarque.Azure\Resources\Project"
Set-CmAzContext -Environment "Development" -ProjectRoot $projectRoot

Describe "Get-CmAzResourceName" {
    Context "Get correct name formats" {
        It "Should fail when no CmAzContext has been set" {
            {   Clear-CmAzContext
                Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Region "UK South" -Name "Keys"
            } | Should Throw "No Cloudmarque Azure context is in place, please run Set-CmAzContext before running this command."
        }
        It "Should not have double separators" {
            Set-CmAzContext -Environment "Development" -ProjectRoot $projectRoot
            $name = Get-CmAzResourceName -Resource "Sample2" -Architecture "Core" -Region "UK South" -Name "MyApp"
            $name | Should -Be "default-myapp-dev-uks-5c1753d6"
        }
        It "Should not have seperator before domain name" {
            $name = Get-CmAzResourceName -Resource "WebApp" -Architecture "Core" -Region "UK South" -Name "MyWebApp"
            $name | Should -Not -Contain "-.azurewebsites.net"
        }
        It "Should not have name length greater then defined" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "Core" -Region "UK South" -Name "MyWindows"
            $name.length | Should -Not -BeGreaterThan 15
        }
    }
    Context "Should report bad parameters" {
        It "Should warn about regions that don't exist" {
            {
                Set-CmAzContext -Environment "Development" -ProjectRoot $projectRoot
                Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "IaaS" -Region "Timbuktoo" -Name "MyApp"
            } | Should Throw "No regional naming convention found in _names\regions.yml for 'Timbuktoo'"
        }
        It "Should fail when using generators that don't exist" {
            {
                Set-CmAzContext -Environment "Development" -ProjectRoot $projectRoot
                Get-CmAzResourceName -Resource "Sample1" -Architecture "IaaS" -Region "Timbuktoo" -Name "MyApp"
            } | Should Throw "No regional naming convention found in _names\regions.yml for 'Timbuktoo'"
        }
        It "Should tolerate incorrectly cased resources" {
            Set-CmAzContext -Environment "Development" -ProjectRoot $projectRoot
            $name = Get-CmAzResourceName -Resource "resourceGroup" -Architecture "Core" -Region "UK South" -Name "Keys"
            $name | Should -Be "rg-keys-core-cebe9fa3"
        }
    }
    Context "Getting correct build ID operations" {
        It "Should append build ID" {
            $name = Get-CmAzResourceName -Resource "Budget" -Architecture "Core" -Region "UK South" -Name "MyBudget" -IncludeBuild
            $name | Should -Be "bud-mybudget-dev-uks-bbef0c49-001"
        }
        It "Should get a VirtualMachine name with build ID" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "Core" -Region "UK South" -Name "MyWindows" -IncludeBuild
            $name | Should -Be "vmmywindows001"
        }
    }
    Context "Should get correct VM names" {
        It "Should get a VirtualMachine name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachine" -Architecture "Core" -Region "UK South" -Name "MyWindows"
            $name | Should -Be "vmmywindowsa941"
        }
        It "Should get a VirtualMachineLinux name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineLinux" -Architecture "Core" -Region "UK South" -Name "MyVirtualMachineLinux"
            $name | Should -Be "vmmyvirtualmachinelinux78361ba6"
        }
        It "Should get a VirtualMachineScaleset name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineScaleset" -Architecture "Core" -Region "UK South" -Name "Scaleset"
            $name | Should -Be "vmssscalesetc29"
        }
        It "Should get a VirtualMachineScalesetLinux name" {
            $name = Get-CmAzResourceName -Resource "VirtualMachineScalesetLinux" -Architecture "Core" -Region "UK South" -Name "MyVirtualMachineScalesetLinux"
            $name | Should -Be "vmssmyvirtualmachinescalesetlinux7785511e"
        }
    }

    Context "Get names from the script" {
        It "Should get a ResourceGroup name" {
            $name = Get-CmAzResourceName -Resource "ResourceGroup" -Architecture "Core" -Region "UK South" -Name "MyResourceGroup"
            $name | Should -Be "rg-myresourcegroup-core-b3760842"
        }
        It "Should get a PolicyDefinition name" {
            $name = Get-CmAzResourceName -Resource "PolicyDefinition" -Architecture "Core" -Region "UK South" -Name "MyPolicyDefinition"
            $name | Should -Be "policy-mypolicydefinition-dev-uks-c01ca77c"
        }
        It "Should get a APImanagementServiceInstance name" {
            $name = Get-CmAzResourceName -Resource "APImanagementServiceInstance" -Architecture "Core" -Region "UK South" -Name "MyAPImanagementServiceInstance"
            $name | Should -Be "apim-myapimanagementserviceinstance-dev-uks-5adcdcab"
        }
        It "Should get a VirtualNetwork name" {
            $name = Get-CmAzResourceName -Resource "VirtualNetwork" -Architecture "Core" -Region "UK South" -Name "MyVirtualNetwork"
            $name | Should -Be "vnet-myvirtualnetwork-dev-uks-df5dee74"
        }
        It "Should get a Subnet name" {
            $name = Get-CmAzResourceName -Resource "Subnet" -Architecture "Core" -Region "UK South" -Name "MySubnet"
            $name | Should -Be "snet-mysubnet-dev-uks-52524038"
        }
        It "Should get a Budget name" {
            $name = Get-CmAzResourceName -Resource "Budget" -Architecture "Core" -Region "UK South" -Name "MyBudget"
            $name | Should -Be "bud-mybudget-dev-uks-bbef0c49"
        }
        It "Should get a AutomationSchedule name" {
            $name = Get-CmAzResourceName -Resource "AutomationSchedule" -Architecture "Core" -Region "UK South" -Name "MyAutomationSchedule"
            $name | Should -Be "atshed-myautomationschedule-dev-uks-13fe9332"
        }
        It "Should get a NetworkInterfaceCard name" {
            $name = Get-CmAzResourceName -Resource "NetworkInterfaceCard" -Architecture "Core" -Region "UK South" -Name "MyNetworkInterfaceCard"
            $name | Should -Be "nic-mynetworkinterfacecard-dev-uks-d3a7f144"
        }
        It "Should get a PublicIPAddress name" {
            $name = Get-CmAzResourceName -Resource "PublicIPAddress" -Architecture "Core" -Region "UK South" -Name "MyPublicIPAddress"
            $name | Should -Be "pip-mypublicipaddress-dev-uks-db600510"
        }
        It "Should get a LoadbalancerInternal name" {
            $name = Get-CmAzResourceName -Resource "LoadbalancerInternal" -Architecture "Core" -Region "UK South" -Name "MyLoadbalancerInternal"
            $name | Should -Be "lbi-myloadbalancerinternal-dev-uks-5dba7d4b"
        }
        It "Should get a LoadbalancerExternal name" {
            $name = Get-CmAzResourceName -Resource "LoadbalancerExternal" -Architecture "Core" -Region "UK South" -Name "MyLoadbalancerExternal"
            $name | Should -Be "lbe-myloadbalancerexternal-dev-uks-6a9269b3"
        }
        It "Should get a NetworkSecurityGroup name" {
            $name = Get-CmAzResourceName -Resource "NetworkSecurityGroup" -Architecture "Core" -Region "UK South" -Name "MyNetworkSecurityGroup"
            $name | Should -Be "nsg-mynetworksecuritygroup-e856f8dd"
        }
        It "Should get a ApplicationSecurityGroup name" {
            $name = Get-CmAzResourceName -Resource "ApplicationSecurityGroup" -Architecture "Core" -Region "UK South" -Name "MyApplicationSecurityGroup"
            $name | Should -Be "asg-myapplicationsecuritygroup-dev-uks-fa2ec1a4"
        }
        It "Should get a LocalNetworkGateway name" {
            $name = Get-CmAzResourceName -Resource "LocalNetworkGateway" -Architecture "Core" -Region "UK South" -Name "MyLocalNetworkGateway"
            $name | Should -Be "lgw-mylocalnetworkgateway-dev-uks-bb2f3561"
        }
        It "Should get a VirtualNetworkGateway name" {
            $name = Get-CmAzResourceName -Resource "VirtualNetworkGateway" -Architecture "Core" -Region "UK South" -Name "MyVirtualNetworkGateway"
            $name | Should -Be "vgw-myvirtualnetworkgateway-dev-uks-b4f37153"
        }
        It "Should get a VPNconnection name" {
            $name = Get-CmAzResourceName -Resource "VPNconnection" -Architecture "Core" -Region "UK South" -Name "MyVPNconnection"
            $name | Should -Be "cn-myvpnconnection-239e4329"
        }
        It "Should get a ApplicationGateway name" {
            $name = Get-CmAzResourceName -Resource "ApplicationGateway" -Architecture "Core" -Region "UK South" -Name "MyApplicationGateway"
            $name | Should -Be "agw-myapplicationgateway-dev-uks-c9ff6d91"
        }
        It "Should get a RouteTable name" {
            $name = Get-CmAzResourceName -Resource "RouteTable" -Architecture "Core" -Region "UK South" -Name "MyRouteTable"
            $name | Should -Be "route-myroutetable"
        }
        It "Should get a TrafficManagerProfile name" {
            $name = Get-CmAzResourceName -Resource "TrafficManagerProfile" -Architecture "Core" -Region "UK South" -Name "MyTrafficManagerProfile"
            $name | Should -Be "traf-mytrafficmanagerprofile-dev-uks-9c6018a6"
        }
        It "Should get a Disk name" {
            $name = Get-CmAzResourceName -Resource "Disk" -Architecture "Core" -Region "UK South" -Name "MyDisk"
            $name | Should -Be "dsk-mydisk-dev-uks-a64de35f"
        }
        It "Should get a AvailabilitySet name" {
            $name = Get-CmAzResourceName -Resource "AvailabilitySet" -Architecture "Core" -Region "UK South" -Name "MyAvailabilitySet"
            $name | Should -Be "avail-myavailabilityset-dev-uks-51d447bb"
        }
        It "Should get a VMStorageAccount name" {
            $name = Get-CmAzResourceName -Resource "VMStorageAccount" -Architecture "Core" -Region "UK South" -Name "MyVMStorageAccount"
            $name | Should -Be "stvmmyvmstorageaccounte4c228da"
        }
        It "Should get a AzureArcconnectedmachine name" {
            $name = Get-CmAzResourceName -Resource "AzureArcconnectedmachine" -Architecture "Core" -Region "UK South" -Name "MyAzureArcconnectedmachine"
            $name | Should -Be "arcm-myazurearcconnectedmachine-dev-uks-296f1488"
        }
        It "Should get a ContainerInstance name" {
            $name = Get-CmAzResourceName -Resource "ContainerInstance" -Architecture "Core" -Region "UK South" -Name "MyContainerInstance"
            $name | Should -Be "aci-mycontainerinstance-dev-uks-154a81a7"
        }
        It "Should get a AKSCluster name" {
            $name = Get-CmAzResourceName -Resource "AKSCluster" -Architecture "Core" -Region "UK South" -Name "MyAKSCluster"
            $name | Should -Be "aks-myakscluster-dev-uks-6cdf81bd"
        }
        It "Should get a ServiceFabricCluster name" {
            $name = Get-CmAzResourceName -Resource "ServiceFabricCluster" -Architecture "Core" -Region "UK South" -Name "MyServiceFabricCluster"
            $name | Should -Be "sf-myservicefabriccluster-dev-uks-1a3bab9f"
        }
        It "Should get a AppServiceEnvironment name" {
            $name = Get-CmAzResourceName -Resource "AppServiceEnvironment" -Architecture "Core" -Region "UK South" -Name "MyAppServiceEnvironment"
            $name | Should -Be "ase-myappserviceenvironment-dev-uks-1d57e19d"
        }
        It "Should get a AppServicePlan name" {
            $name = Get-CmAzResourceName -Resource "AppServicePlan" -Architecture "Core" -Region "UK South" -Name "MyAppServicePlan"
            $name | Should -Be "plan-myappserviceplan-dev-uks-efffb94e"
        }
        It "Should get a WebApp name" {
            $name = Get-CmAzResourceName -Resource "WebApp" -Architecture "Core" -Region "UK South" -Name "MyWebApp" -IncludeBuild
            $name | Should -Be "app-mywebapp-dev-909260e2-001"
        }
        It "Should get a FunctionApp name" {
            $name = Get-CmAzResourceName -Resource "FunctionApp" -Architecture "Core" -Region "UK South" -Name "MyFunctionApp" -IncludeBuild
            $name | Should -Be "func-myfunctionapp-dev-4f6634ae-001"
        }
        It "Should get a CloudService name" {
            $name = Get-CmAzResourceName -Resource "CloudService" -Architecture "Core" -Region "UK South" -Name "MyCloudService" -IncludeBuild
            $name | Should -Be "cld-mycloudservice-dev-71a7c051-001"
        }
        It "Should get a NotificationHubs name" {
            $name = Get-CmAzResourceName -Resource "NotificationHubs" -Architecture "Core" -Region "UK South" -Name "MyNotificationHubs"
            $name | Should -Be "ntf-mynotificationhubs-dev"
        }
        It "Should get a NotificationHubsnamespace name" {
            $name = Get-CmAzResourceName -Resource "NotificationHubsnamespace" -Architecture "Core" -Region "UK South" -Name "MyNotificationHubsnamespace"
            $name | Should -Be "ntfns-mynotificationhubsnamespace-dev"
        }
        It "Should get a AzureSQLDatabaseserver name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDatabaseserver" -Architecture "Core" -Region "UK South" -Name "MyAzureSQLDatabaseserver"
            $name | Should -Be "sql-myazuresqldatabaseserver-dev"
        }
        It "Should get a AzureSQLDatabase name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDatabase" -Architecture "Core" -Region "UK South" -Name "MyAzureSQLDatabase"
            $name | Should -Be "sqldb-myazuresqldatabase-dev"
        }
        It "Should get a AzureCosmosDBdatabase name" {
            $name = Get-CmAzResourceName -Resource "AzureCosmosDBdatabase" -Architecture "Core" -Region "UK South" -Name "MyAzureCosmosDBdatabase"
            $name | Should -Be "cosmos-myazurecosmosdbdatabase-dev"
        }
        It "Should get a AzureCacheforRedisinstance name" {
            $name = Get-CmAzResourceName -Resource "AzureCacheforRedisinstance" -Architecture "Core" -Region "UK South" -Name "MyAzureCacheforRedisinstance"
            $name | Should -Be "redis-myazurecacheforredisinstance-dev"
        }
        It "Should get a MySQLdatabase name" {
            $name = Get-CmAzResourceName -Resource "MySQLdatabase" -Architecture "Core" -Region "UK South" -Name "MyMySQLdatabase"
            $name | Should -Be "mysql-mymysqldatabase-dev"
        }
        It "Should get a PostgreSQLdatabase name" {
            $name = Get-CmAzResourceName -Resource "PostgreSQLdatabase" -Architecture "Core" -Region "UK South" -Name "MyPostgreSQLdatabase"
            $name | Should -Be "psql-mypostgresqldatabase-dev"
        }
        It "Should get a AzureSQLDataWarehouse name" {
            $name = Get-CmAzResourceName -Resource "AzureSQLDataWarehouse" -Architecture "Core" -Region "UK South" -Name "MyAzureSQLDataWarehouse"
            $name | Should -Be "sqldw-myazuresqldatawarehouse-dev"
        }
        It "Should get a AzureSynapseAnalytics name" {
            $name = Get-CmAzResourceName -Resource "AzureSynapseAnalytics" -Architecture "Core" -Region "UK South" -Name "MyAzureSynapseAnalytics"
            $name | Should -Be "syn-myazuresynapseanalytics-dev-uks-4199a6bf"
        }
        It "Should get a SQLServerStretchDatabase name" {
            $name = Get-CmAzResourceName -Resource "SQLServerStretchDatabase" -Architecture "Core" -Region "UK South" -Name "MySQLServerStretchDatabase"
            $name | Should -Be "sqlstrdb-mysqlserverstretchdatabase-dev"
        }
        It "Should get a Storageaccount name" {
            $name = Get-CmAzResourceName -Resource "Storageaccount" -Architecture "Core" -Region "UK South" -Name "MyStorageaccount"
            $name | Should -Be "stmystorageaccountbd0fa58a"
        }
        It "Should get a AzureStorSimple name" {
            $name = Get-CmAzResourceName -Resource "AzureStorSimple" -Architecture "Core" -Region "UK South" -Name "MyAzureStorSimple"
            $name | Should -Be "ssimpmyazurestorsimple03523493"
        }
        It "Should get a AzureCognitiveSearch name" {
            $name = Get-CmAzResourceName -Resource "AzureCognitiveSearch" -Architecture "Core" -Region "UK South" -Name "MyAzureCognitiveSearch"
            $name | Should -Be "srch-myazurecognitivesearch-dev"
        }
        It "Should get a AzureCognitiveServices name" {
            $name = Get-CmAzResourceName -Resource "AzureCognitiveServices" -Architecture "Core" -Region "UK South" -Name "MyAzureCognitiveServices"
            $name | Should -Be "cog-myazurecognitiveservices-dev"
        }
        It "Should get a AzureMachineLearningworkspace name" {
            $name = Get-CmAzResourceName -Resource "AzureMachineLearningworkspace" -Architecture "Core" -Region "UK South" -Name "MyAzureMachineLearningworkspace"
            $name | Should -Be "mlw-myazuremachinelearningworkspace-dev"
        }
        It "Should get a AzureAnalysisServicesserver name" {
            $name = Get-CmAzResourceName -Resource "AzureAnalysisServicesserver" -Architecture "Core" -Region "UK South" -Name "MyAzureAnalysisServicesserver"
            $name | Should -Be "as-myazureanalysisservicesserver-dev"
        }
        It "Should get a AzureDatabricksworkspace name" {
            $name = Get-CmAzResourceName -Resource "AzureDatabricksworkspace" -Architecture "Core" -Region "UK South" -Name "MyAzureDatabricksworkspace"
            $name | Should -Be "dbw-myazuredatabricksworkspace-dev"
        }
        It "Should get a AzureStreamAnalytics name" {
            $name = Get-CmAzResourceName -Resource "AzureStreamAnalytics" -Architecture "Core" -Region "UK South" -Name "MyAzureStreamAnalytics"
            $name | Should -Be "asa-myazurestreamanalytics-dev"
        }
        It "Should get a AzureDataFactory name" {
            $name = Get-CmAzResourceName -Resource "AzureDataFactory" -Architecture "Core" -Region "UK South" -Name "MyAzureDataFactory"
            $name | Should -Be "adf-myazuredatafactory-dev"
        }
        It "Should get a DataLakeStoreaccount name" {
            $name = Get-CmAzResourceName -Resource "DataLakeStoreaccount" -Architecture "Core" -Region "UK South" -Name "MyDataLakeStoreaccount"
            $name | Should -Be "dls-mydatalakestoreaccount-dev"
        }
        It "Should get a DataLakeAnalyticsaccount name" {
            $name = Get-CmAzResourceName -Resource "DataLakeAnalyticsaccount" -Architecture "Core" -Region "UK South" -Name "MyDataLakeAnalyticsaccount"
            $name | Should -Be "dla-mydatalakeanalyticsaccount-dev"
        }
        It "Should get a Eventhub name" {
            $name = Get-CmAzResourceName -Resource "Eventhub" -Architecture "Core" -Region "UK South" -Name "MyEventhub"
            $name | Should -Be "evh-myeventhub-dev"
        }
        It "Should get a HDInsightHadoopcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightHadoopcluster" -Architecture "Core" -Region "UK South" -Name "MyHDInsightHadoopcluster"
            $name | Should -Be "hadoop-myhdinsighthadoopcluster-dev"
        }
        It "Should get a HDInsightHBasecluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightHBasecluster" -Architecture "Core" -Region "UK South" -Name "MyHDInsightHBasecluster"
            $name | Should -Be "hbase-myhdinsighthbasecluster-dev"
        }
        It "Should get a HDInsightKafkacluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightKafkacluster" -Architecture "Core" -Region "UK South" -Name "MyHDInsightKafkacluster"
            $name | Should -Be "kafka-myhdinsightkafkacluster-dev"
        }
        It "Should get a HDInsightSparkcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightSparkcluster" -Architecture "Core" -Region "UK South" -Name "MyHDInsightSparkcluster"
            $name | Should -Be "spark-myhdinsightsparkcluster-dev"
        }
        It "Should get a HDInsightStormcluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightStormcluster" -Architecture "Core" -Region "UK South" -Name "MyHDInsightStormcluster"
            $name | Should -Be "storm-myhdinsightstormcluster-dev"
        }
        It "Should get a HDInsightMLServicescluster name" {
            $name = Get-CmAzResourceName -Resource "HDInsightMLServicescluster" -Architecture "Core" -Region "UK South" -Name "MyHDInsightMLServicescluster"
            $name | Should -Be "mls-myhdinsightmlservicescluster-dev"
        }
        It "Should get a IoThub name" {
            $name = Get-CmAzResourceName -Resource "IoThub" -Architecture "Core" -Region "UK South" -Name "MyIoThub"
            $name | Should -Be "iot-myiothub-dev"
        }
        It "Should get a PowerBIEmbedded name" {
            $name = Get-CmAzResourceName -Resource "PowerBIEmbedded" -Architecture "Core" -Region "UK South" -Name "MyPowerBIEmbedded"
            $name | Should -Be "pbi-mypowerbiembedded-dev"
        }
        It "Should get a LogicApps name" {
            $name = Get-CmAzResourceName -Resource "LogicApps" -Architecture "Core" -Region "UK South" -Name "MyLogicApps"
            $name | Should -Be "logic-mylogicapps-dev"
        }
        It "Should get a ServiceBus name" {
            $name = Get-CmAzResourceName -Resource "ServiceBus" -Architecture "Core" -Region "UK South" -Name "MyServiceBus"
            $name | Should -Be "sb-myservicebus-dev"
        }
        It "Should get a ServiceBusQueue name" {
            $name = Get-CmAzResourceName -Resource "ServiceBusQueue" -Architecture "Core" -Region "UK South" -Name "MyServiceBusQueue"
            $name | Should -Be "sbq-myservicebusqueue-dev"
        }
        It "Should get a ServiceBusTopic name" {
            $name = Get-CmAzResourceName -Resource "ServiceBusTopic" -Architecture "Core" -Region "UK South" -Name "MyServiceBusTopic"
            $name | Should -Be "sbt-myservicebustopic-dev"
        }
        It "Should get a Blueprint name" {
            $name = Get-CmAzResourceName -Resource "Blueprint" -Architecture "Core" -Region "UK South" -Name "MyBlueprint"
            $name | Should -Be "bp-myblueprint-dev-uks-8dc25957"
        }
        It "Should get a Keyvault name" {
            $name = Get-CmAzResourceName -Resource "Keyvault" -Architecture "Core" -Region "UK South" -Name "MyKeyvault"
            $name | Should -Be "kv-mykeyvault-uks-d512e232"
        }
        It "Should get a LogAnalyticsworkspace name" {
            $name = Get-CmAzResourceName -Resource "LogAnalyticsworkspace" -Architecture "Core" -Region "UK South" -Name "MyLogAnalyticsworkspace"
            $name | Should -Be "log-myloganalyticsworkspace-dev-uks-03c8a08c"
        }
        It "Should get a ApplicationInsights name" {
            $name = Get-CmAzResourceName -Resource "ApplicationInsights" -Architecture "Core" -Region "UK South" -Name "MyApplicationInsights"
            $name | Should -Be "appi-myapplicationinsights-dev-uks-82f34eb7"
        }
        It "Should get a RecoveryServicesvault name" {
            $name = Get-CmAzResourceName -Resource "RecoveryServicesvault" -Architecture "Core" -Region "UK South" -Name "MyRecoveryServicesvault"
            $name | Should -Be "rsv-myrecoveryservicesvault-dev-uks-40f2e103"
        }
        It "Should get a AzureMigrateproject name" {
            $name = Get-CmAzResourceName -Resource "AzureMigrateproject" -Architecture "Core" -Region "UK South" -Name "MyAzureMigrateproject"
            $name | Should -Be "migr-myazuremigrateproject-dev-uks-e02e0d51"
        }
        It "Should get a DatabaseMigrationServiceinstance name" {
            $name = Get-CmAzResourceName -Resource "DatabaseMigrationServiceinstance" -Architecture "Core" -Region "UK South" -Name "MyDatabaseMigrationServiceinstance"
            $name | Should -Be "dms-mydatabasemigrationserviceinstance-dev-uks-f4a56712"
        }
        It "Should get a OSDisk name" {
            $name = Get-CmAzResourceName -Resource "OSDisk" -Architecture "Core" -Region "UK South" -Name "MyOSDisk"
            $name | Should -Be "osdk-myosdisk-dev-uks-6823383f"
        }
        It "Should get a DataDisk name" {
            $name = Get-CmAzResourceName -Resource "DataDisk" -Architecture "Core" -Region "UK South" -Name "MyDataDisk"
            $name | Should -Be "ddk-mydatadisk-dev-uks-1e584fe6"
        }
        It "Should get a ComputerName name" {
            $name = Get-CmAzResourceName -Resource "ComputerName" -Architecture "Core" -Region "UK South" -Name "MyComputerName"
            $name | Should -Be "compmycomputernameb4acd664"
        }
        It "Should get a Automation name" {
            $name = Get-CmAzResourceName -Resource "Automation" -Architecture "Core" -Region "UK South" -Name "MyAutomation"
            $name | Should -Be "auto-myautomation-dev-uks-31397c98"
        }
        It "Should get a CdnProfile name" {
            $name = Get-CmAzResourceName -Resource "CdnProfile" -Architecture "Core" -Region "UK South" -Name "MyCdnProfile"
            $name | Should -Be "cdn-mycdnprofile-dev-uks-f6e7916a"
        }
        It "Should get a ActionGroup name" {
            $name = Get-CmAzResourceName -Resource "ActionGroup" -Architecture "Core" -Region "UK South" -Name "MyActionGroup"
            $name | Should -Be "agrp-myactiongroup-dev-uks-b5b8d0c1"
        }
        It "Should get a ActionGroupReceiver name" {
            $name = Get-CmAzResourceName -Resource "ActionGroupReceiver" -Architecture "Core" -Region "UK South" -Name "MyActionGroupReceiver"
            $name | Should -Be "agrprec-myactiongroupreceiver-dev-uks-e01519e8"
        }
        It "Should get a FrontDoor name" {
            $name = Get-CmAzResourceName -Resource "FrontDoor" -Architecture "Core" -Region "UK South" -Name "MyFrontDoor"
            $name | Should -Be "fd-myfrontdoor-dev-uks-27fe25ca"
        }
        It "Should get a ServiceHealthAlert name" {
            $name = Get-CmAzResourceName -Resource "ServiceHealthAlert" -Architecture "Core" -Region "UK South" -Name "MyServiceHealthAlert"
            $name | Should -Be "svceha-myservicehealthalert-dev-uks-277d1c78"
        }
        It "Should get a BastionHost name" {
            $name = Get-CmAzResourceName -Resource "BastionHost" -Architecture "Core" -Region "UK South" -Name "MyBastionHost"
            $name | Should -Be "bastion-mybastionhost-dev-uks-3f2784a4"
        }
        It "Should get a Endpoint name" {
            $name = Get-CmAzResourceName -Resource "Endpoint" -Architecture "Core" -Region "UK South" -Name "MyEndpoint"
            $name | Should -Be "ep-myendpoint-dev-uks-25d99962"
        }
    }
}