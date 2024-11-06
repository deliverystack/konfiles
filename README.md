# konfiles: Bash Script to Download Kontent.ai Content Type Definitions and Entries as JSON Files
This clog describes a prototype Bourne shell script that attempts to download all content type definitions and entries from the Kontent.ai headless content management system. You can use a similar technique with any CMS.

For context, see:

- https://deliverystack.net/2024/10/21/static-file-export-with-headless-cms/

We can use Kontent.api Webservice APIs to retrieve content entry definitions and entries. We may need to iterate over pages of records, which means invoking that Webservice API repeatedly. We can request the first page, which indicates the number of pages, and then we can request each additional page. We can retrieve the subsequent pages in parallel, but at some volume, we may need to introduce throttling.

## Webservice API Paging

Quickly, an overview of how paging typically works with Webservice APIs. When retrieving all data as in this example and in other cases where data volumes could be high, Webservice APIs break data into pages of a given size and require callers to invoke the API repeatedly, passing parameters to specify page numbers, which implies that data is in a consistent order.

Typically, you call the API to retrieve the first page, which indicates the size of the page and the number of pages. You then call the API again for any pages that you want. This typically uses three parameters that can go by different names:

- `total`: The total number of records.
- `limit`/`pageSize`: The page size.
- `offset`/`skip`: The number of records to skip.

## Kontent.ai Download Implementation

//TODO: link

I have found Bash shell scripts to be efficient for prototyping, although jq syntax is a bit cumbersome (though efficient). If you think about it, the command line exposes a sort of API that provides very high-level functionality, such as grep with filename globbing, but also supports minute operations such as `sed`. If I understand correctly, spawning a process on the command line is a relatively expensive operation in machine resources, so shell may not be the most efficient mechanism available. 

## The Script

The preamble of the script defines some variables, some of which should come from the environment or elsewhere, before ensuring that directories exist for the output files.

### Functions

We have to define some functions before we can use them. The `download_entries_for_content_type()` function creates files for each entry in an individual content type.

The `flatten_entry()` function converts a Kontent.ai entry from this format:

``` json
{
  "system": {
    "id": "270a6b85-d95d-4863-96ed-6040188227d8",
    "name": "Home",
    "codename": "home",
    "language": "default",
    "type": "simplepage",
    "collection": "default",
    "sitemap_locations": [],
    "last_modified": "2024-11-05T19:36:21.9866592Z",
    "workflow": "default",
    "workflow_step": "published"
  },
  "elements": {
    "commoncontent__title": {
      "type": "text",
      "name": "Title",
      "value": "Everything points to this item"
    },
    "commoncontent__description": {
      "type": "text",
      "name": "Description",
      "value": "Home Page Description"
    },
    "commoncontent__mainimage": {
      "type": "asset",
      "name": "MainImage",
      "value": [
        {
          "name": "photo-1574068468668-a05a11f871da.jpg",
          "description": null,
          "type": "image/jpeg",
          "size": 871156,
          "url": "https://assets-us-01.kc-usercontent.com:443/97d53770-a796-0065-c458-d65e6dcfc537/87dccfda-3798-476b-8128-cee6b37c82f6/photo-1574068468668-a05a11f871da.jpg",
          "width": 2250,
          "height": 4000,
          "renditions": {}
        }
      ]
    },
    "pagecontent__url": {
      "type": "text",
      "name": "URL",
      "value": "/"
    },
    "pagecontent__maincomponents": {
      "type": "modular_content",
      "name": "MainComponents",
      "value": [
        "first_banner_component",
        "first_image_collection_component",
        "first_rte_component"
      ]
    }
  }
}
```

To this:

``` json
{
  "id": "270a6b85-d95d-4863-96ed-6040188227d8",
  "name": "Home",
  "codename": "home",
  "language": "default",
  "type": "simplepage",
  "collection": "default",
  "sitemap_locations": [],
  "last_modified": "2024-11-05T19:36:21.9866592Z",
  "workflow": "default",
  "workflow_step": "published",
  "commoncontent__title": "Everything points to this item",
  "commoncontent__description": "Home Page Description",
  "commoncontent__mainimage": [
    {
      "name": "photo-1574068468668-a05a11f871da.jpg",
      "description": null,
      "type": "image/jpeg",
      "size": 871156,
      "url": "https://assets-us-01.kc-usercontent.com:443/97d53770-a796-0065-c458-d65e6dcfc537/87dccfda-3798-476b-8128-cee6b37c82f6/photo-1574068468668-a05a11f871da.jpg",
      "width": 2250,
      "height": 4000,
      "renditions": {}
    }
  ],
  "pagecontent__url": "/",
  "pagecontent__maincomponents": [
    "first_banner_component",
    "first_image_collection_component",
    "first_rte_component"
  ]
}
```

The process_entries()  function generates additional files from the raw .json files. Specifically, it flattens the entry to a file named after the entry. Interestingly, if that value contains slash (/) characters, this constructs a file path, which is similar to the following URL logic. If the URL field of the entry contains a value, then the script duplicates the flattened entry to a file at that path. Because the item with URL / would correspond to the file /.json, it uses /home.json in this case.

### Script Body

-Creates any required directories.
-Stores the content type definitions.
-Stores all entries as files.

