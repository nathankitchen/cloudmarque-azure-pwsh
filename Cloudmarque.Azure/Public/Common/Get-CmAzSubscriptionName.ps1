function Get-CmAzSubscriptionName {
	<#
		.Synopsis
		 A helper function to get the current subscription name (deprecated, do not use)

		.Description
		 A helper function to get the current subscription name. WARNING: Deprecated - this function will be removed in a future release.

		.Component
		 Common

		.Example
		 Get-CmAzSubscriptionName
    #>
    $context = get-AzContext

	if ($context) {
		"Subscription: $($context.subscription.Name)-$($context.subscription.Id)"
	}
	else {
		throw "No azure context found, please sign into Azure."
	}
}