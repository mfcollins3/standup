// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Azure.Storage.Blobs;
using Azure.Storage.Sas;

namespace Api.Services;

public sealed class SasUrlService(BlobServiceClient blobServiceClient) : ISasUrlService
{
    private const string ContainerName = "status-videos";

    public async Task<SasUrlResult> GenerateSasUrlAsync(
        string blobPath,
        CancellationToken cancellationToken = default)
    {
        var startsOn = DateTimeOffset.UtcNow.AddMinutes(-5);
        var expiresOn = DateTimeOffset.UtcNow.AddMinutes(15);

        var userDelegationKey = await blobServiceClient.GetUserDelegationKeyAsync(
            startsOn,
            expiresOn,
            cancellationToken);

        var sasBuilder = new BlobSasBuilder
        {
            BlobContainerName = ContainerName,
            BlobName = blobPath,
            Resource = "b",
            StartsOn = startsOn,
            ExpiresOn = expiresOn,
            Protocol = SasProtocol.Https
        };
        sasBuilder.SetPermissions(BlobSasPermissions.Write | BlobSasPermissions.Create);

        var blobUriBuilder = new BlobUriBuilder(blobServiceClient.Uri)
        {
            BlobContainerName = ContainerName,
            BlobName = blobPath,
            Sas = sasBuilder.ToSasQueryParameters(userDelegationKey, blobServiceClient.AccountName)
        };

        return new SasUrlResult(blobUriBuilder.ToUri(), expiresOn);
    }
}
