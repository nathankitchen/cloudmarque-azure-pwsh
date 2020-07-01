function Get-CmAzSubscriptionName {

    $context = get-AzContext

	if ($context) {
		"Subscription: $($context.subscription.Name)-$($context.subscription.Id)"
	}
	else {
		throw "No azure context found, please sign into Azure."
	}
}