# konfiles: Bash Shell Script to Download Kontent.ai Content Type Definitions and Entries as JSON Files

This clog describes a prototype Bash shell script that attempts to download all content type definitions and entries from the Kontent.ai headless content management system. You can use a similar technique with any CMS.

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

I have found Bash shell scripts to be efficient for prototyping, although jq syntax is a bit cumbersome (though efficient). If you think about it, the command line exposes a sort of API that provides very high-level functionality, such as grep with filename globbing, but also supports minute operations such as `sed`. If I understand correctly, spawning a process on the command line is a relatively expensive operation in machine resources, so shell may not be the most efficient mechanism available. 

## The Script

The preamble of the script defines some variables, some of which should come from the environment or elsewhere, before ensuring that directories exist for the output files.

- https://github.com/deliverystack/konfiles/blob/main/konfiles.bash

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

The `process_entries()` function generates additional files from the raw `.json` files. Specifically, it flattens the entry to a file named after the entry. Interestingly, if that value contains slash (`/`) characters, this constructs a file path, which is similar to the following URL logic. If the URL field of the entry contains a value, then the script duplicates the flattened entry to a file at that path. Because the item with URL `/` would correspond to the file `/.json`, it uses `/home.json` in this case.

### Script Body

- Creates any required directories.
- Stores the content type definitions.
- Stores all entries as files.

## Index Static JSON Files from Headless CMS

Data-driven front-end code, such as to generate navigation, needs to know what entries exist. Frequently recursing a directory structure would be impractical, and anyway we’re using HTTP to access the data. After we generate the JSON files, we can run a script that generates index.json files in each subdirectory to contain metadata extracted from each of those files.

- https://github.com/deliverystack/konfiles/blob/main/index.bash

Individual entries look like this:

``` json
{
  "entries": [
    {
      "file": "contact.json",
      "title": "QSxoq0I0 mgTKI7YFrso"
    },
    {
      "file": "about.json",
      "title": "amDHIOpNYsrHirJr4ZYA"
    },
    {
      "file": "home.json",
      "title": "IQM0KHHuq7e2CZJ1 6U7"
    },
    {
      "file": "services.json",
      "title": "ZmYxtBAHJ7HCu5Y2fnVD"
    }
  ],
  "children": [
    {
      "name": "files"
    },
    {
      "name": "info"
    },
    {
      "name": "products"
    }
  ]
}

```

We can use another script that aggregates those index.json files. 

- https://github.com/deliverystack/konfiles/blob/main/catindex.bash

The consolidated data looks like this:

``` json
{
  "entries": [
    {
      "file": "contact.json",
      "title": "QSxoq0I0 mgTKI7YFrso"
    },
    {
      "file": "about.json",
      "title": "amDHIOpNYsrHirJr4ZYA"
    },
    {
      "file": "home.json",
      "title": "IQM0KHHuq7e2CZJ1 6U7"
    },
    {
      "file": "services.json",
      "title": "ZmYxtBAHJ7HCu5Y2fnVD"
    }
  ],
  "children": [
    {
      "name": "files"
    },
    {
      "name": "info"
    },
    {
      "name": "products"
    }
  ],
  "subdirectories": {
    "files": {
      "entries": [],
      "children": [
        {
          "name": "content_types"
        },
        {
          "name": "entries"
        },
        {
          "name": "flattened_entries"
        },
        {
          "name": "url_based_structure"
        }
      ],
      "subdirectories": {
        "content_types": {},
        "entries": {
          "entries": [
            {
              "file": "_simple.json",
              "title": "/simple"
            },
            {
              "file": "_simple_page.json",
              "title": "/simple/page"
            },
            {
              "file": "home.json",
              "title": "Everything points to this item"
            }
          ],
          "children": [
            {
              "name": "bannercomponent"
            },
            {
              "name": "imagecollection"
            },
            {
              "name": "imagecollectioncomponent"
            },
            {
              "name": "rtecomponent"
            },
            {
              "name": "rtetemplate"
            },
            {
              "name": "simplepage"
            }
          ],
          "subdirectories": {
            "bannercomponent": {},
            "imagecollection": {},
            "imagecollectioncomponent": {},
            "rtecomponent": {},
            "rtetemplate": {},
            "simplepage": {}
          }
        },
        "flattened_entries": {
          "entries": [],
          "children": [
            {
              "name": "bannercomponent"
            },
            {
              "name": "imagecollection"
            },
            {
              "name": "imagecollectioncomponent"
            },
            {
              "name": "rtecomponent"
            },
            {
              "name": "rtetemplate"
            },
            {
              "name": "simplepage"
            }
          ],
          "subdirectories": {
            "bannercomponent": {},
            "imagecollection": {},
            "imagecollectioncomponent": {},
            "rtecomponent": {},
            "rtetemplate": {},
            "simplepage": {
              "entries": [
                {
                  "file": "270a6b85-d95d-4863-96ed-6040188227d8.json",
                  "title": "Everything points to this item"
                },
                {
                  "file": "9d0f1c68-52c5-4942-85ef-75b27aa517c8.json",
                  "title": "/simple/page"
                },
                {
                  "file": "c045b184-4b09-4d45-a75a-a0f4f3a99b4d.json",
                  "title": "/simple"
                },
                {
                  "file": "home.json",
                  "title": "Everything points to this item"
                },
                {
                  "file": "simple.json",
                  "title": "/simple"
                }
              ],
              "children": [
                {
                  "name": "simple"
                }
              ],
              "subdirectories": {
                "simple": {
                  "entries": [],
                  "children": [
                    {
                      "name": "page"
                    }
                  ],
                  "subdirectories": {
                    "page": {
                      "entries": [],
                      "children": [
                        {
                          "name": "deeper"
                        }
                      ],
                      "subdirectories": {
                        "deeper": {
                          "entries": [],
                          "children": [
                            {
                              "name": "than"
                            }
                          ],
                          "subdirectories": {
                            "than": {
                              "entries": [
                                {
                                  "file": "though.json",
                                  "title": "/simple/page"
                                }
                              ],
                              "children": []
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "url_based_structure": {
          "entries": [
            {
              "file": "home.json",
              "title": "Everything points to this item"
            },
            {
              "file": "simple.json",
              "title": "/simple"
            }
          ],
          "children": [
            {
              "name": "simple"
            }
          ],
          "subdirectories": {
            "simple": {
              "entries": [
                {
                  "file": "page.json",
                  "title": "/simple/page"
                }
              ],
              "children": []
            }
          }
        }
      }
    },
    "info": {
      "entries": [
        {
          "file": "info1.json",
          "title": "sZXZR3y5ChFa7z5z5boa"
        },
        {
          "file": "info2.json",
          "title": "o2oNG1in9nrIg5XlZ8i2"
        },
        {
          "file": "info3.json",
          "title": "am4i87Uit2f26yPHCKIo"
        }
      ],
      "children": [
        {
          "name": "subinfo"
        }
      ],
      "subdirectories": {
        "subinfo": {
          "entries": [
            {
              "file": "subinfo3.json",
              "title": "JUvzBowcRqYsszweAOCo"
            },
            {
              "file": "subinfo1.json",
              "title": "GMfCHkIVQxnRpokiMZKj"
            },
            {
              "file": "subinfo2.json",
              "title": "zWxdp5FieKBZHq2Ty1Qp"
            }
          ],
          "children": [
            {
              "name": "nested_subinfo"
            }
          ],
          "subdirectories": {
            "nested_subinfo": {
              "entries": [
                {
                  "file": "nested2.json",
                  "title": "yjms91ee4lI5KmJEitU8"
                },
                {
                  "file": "nested3.json",
                  "title": "gyUmrCEypCDkoybSJVid"
                },
                {
                  "file": "nested1.json",
                  "title": "pZ2q91sAHo4n W8YtKXM"
                }
              ],
              "children": []
            }
          }
        }
      }
    },
    "products": {
      "entries": [
        {
          "file": "furniture.json",
          "title": "KAi6eh6hcJMQf2Uhli4Y"
        },
        {
          "file": "electronics.json",
          "title": "iFv9hnOlJBViJEidQVJo"
        },
        {
          "file": "appliances.json",
          "title": "SwuBZ3G3yJ249V h6heT"
        },
        {
          "file": "books.json",
          "title": "dATQCW3wrkGFcwwtIty9"
        }
      ],
      "children": [
        {
          "name": "subdir1"
        },
        {
          "name": "subdir2"
        }
      ],
      "subdirectories": {
        "subdir1": {
          "entries": [
            {
              "file": "subcategory2.json",
              "title": "XLlpWczG2VY7RDht7t95"
            },
            {
              "file": "subcategory3.json",
              "title": "LGyxzQr7F191FlhE3IKs"
            },
            {
              "file": "subcategory1.json",
              "title": "wWHV3onmjDaAq42j2wxZ"
            }
          ],
          "children": []
        },
        "subdir2": {
          "entries": [
            {
              "file": "subcategory6.json",
              "title": "F7zG1JlsEGGGTKaCC10S"
            },
            {
              "file": "subcategory4.json",
              "title": "R2agl ojVDC5vECJaOy5"
            },
            {
              "file": "subcategory5.json",
              "title": "ejZN9wDo6SsbXw2QWyox"
            }
          ],
          "children": []
        }
      }
    }
  }
}
```


