require "iiif_to_jekyll/version"
require "iiif_to_jekyll/annotation"
require "pry"
require 'iiif/presentation'
require 'date'
require 'open-uri'

module IiifToJekyll

  class Error < StandardError; end
  
  # jekyll volume pages directory
  VOLUME_PAGE_DIR = '_volume_pages'
  # jekyll annotation directory
  ANNOTATION_DIR = '_annotations'
  # jekyll config file
  CONFIG_FILE = '_config.yml'
  # jekyll data dir
  DATA_DIR = '_data'
  # tags data file
  TAG_FILE = File.join(DATA_DIR, 'tags.yml')
  # directory where tag stub pages should be created
  TAG_DIR = 'tags'

  # Import IIIF metadata, structure, and annotation content into a jekyll site
  # @param dirname [String] directory containing Readux export
  #
  # This code is based extensively on teifacsimile-to-jekyll
  def self.import(dirname, output_dir, opts={})
    manifest = load_manifest(dirname)

    Dir.chdir(output_dir) do
      write_volume_pages(manifest, opts)

      write_annotations(manifest, dirname, opts)

# => Functionality not implemented yet in Readux 2
#    output_tags(teidoc.tags, **opts)

# TODO: what does this do?
    # # copy annotated tei into jekyll site
    # opts['tei_filename'] = 'tei.xml'
    # FileUtils.copy_file(filename, opts['tei_filename'])

      write_site_config(manifest, opts)

    end
  end

  # TODO: Why update?  Does it start with the theme?

  # Update jekyll site config with values from the IIIF manifest
  # and necessary configurations for setting up jekyll collections
  # of volume pages and annotation content.
  # @param manifest [TeiFacsimile]
  # @param configfile [String] path to existing config file to be updated
  def self.update_site_config(manifest, configfile, opts={})
      siteconfig = YAML.load_file(configfile)

      # set site title and subtitle from the tei
      siteconfig['title'] = manifest.label
#      siteconfig['tagline'] = teidoc.title_statement.subtitle

      # placeholder description for author to edit (todo: include annotation author name here?)
      siteconfig['description'] = 'An annotated digital edition created with <a href="http://readux.library.emory.edu/">Readux</a>'

      # add urls to readux volume and pdf

      # use first page (which should be the cover) as a default splash
      # image for the home page
      siteconfig['homepage_image'] = manifest.sequences.first.canvases.first.images.first.resource['@id']


      # TODO
      # add image dimensions to config so that thumbnail display can be tailored
      # to the current volume page size
      # thumbnail_width, thumbnail_height = FastImage.size(teidoc.pages[0].images_by_type['thumbnail'].url)
      # sm_thumbnail_width, sm_thumbnail_height = FastImage.size(teidoc.pages[0].images_by_type['small-thumbnail'].url)
      # page_img_width, page_img_height = FastImage.size(teidoc.pages[0].images_by_type['page'].url)
      siteconfig['image_size'] = {
          # 'page' => {'width' => page_img_width, 'height' => page_img_height},
          # 'thumbnail' => {'width' => thumbnail_width, 'height' => thumbnail_height},
          # 'small-thumbnail' => {'width' => sm_thumbnail_width, 'height' => sm_thumbnail_height}
      }

      # TODO deal with this
      # add source publication information, including
      # urls to volume and pdf on readux
#      original = teidoc.source_bibl['original']
      source_info = {
        'title' => manifest.label, 
        # 'author' => original.author,
          # 'date' => original.date,
          # 'url' => teidoc.source_bibl['digital'].references['digital-edition'].target,
          # 'pdf_url' => teidoc.source_bibl['digital'].references['pdf'].target,
          'via_readux' => true
        }

      # preliminary publication information for the annotated edition
      pub_info = {
        'title' => manifest.label,
          'date' => Date.today.strftime("%Y"), # current year
#          'author' => original.author,
          'editors' => [],
      }


      # configure extra js for volume pages based on deep zoom configuration
      volume_js = ['volume-page.js', 'hammer.min.js']
      if opts[:deep_zoom]
          volume_js.push('deepzoom.js').push('openseadragon.min.js')
      end

      # TODO: read annotator names
      # # add all annotator names to the document as editors
      # # of the annotated edition; use username if name is empty
      # teidoc.resp.each do |resp, name|
      #     pub_info['editors']  << (name.value != '' ? name.value : resp)
      # end

      # configure collections specific to tei facsimile + annotation data
      siteconfig.merge!({
          'source_info' => source_info,
          'publication_info' => pub_info,
          'collections' => {
              # NOTE: annotations *must* come first, so content can
              # be rendered for display in volume pages templates
              'annotations' => {
                  'output' => true,
                  'permalink' => '/annotations/:path/'
              },
              'volume_pages' => {
                  'output' => true,
                  'permalink' => '/pages/:path/'
              },
          },
          'defaults' => [{
             'scope' => {
                  'path' => '',
                  'type' => 'volume_pages',
              },
              'values' => {
                  'layout' => 'volume_page',
                  'short_label' => 'p.',
                  'deep_zoom' => opts[:deep_zoom],
                  'extra_js' => volume_js
              }
            },
            {'scope' => {
                  'path' => '',
                  'type' => 'annotations',
              },
              'values' => {
                  'layout' => 'annotation'
              }
            }
        ]
      })
      # TODO:
      # - author information from resp statement?

      # NOTE: this generates a config file without any comments,
      # and removes existing comments - which is not very user-friendly;
      # look into generating/updating config with comments

      File.open(configfile, 'w') do |file|
          # write out updated site config
          file.write siteconfig.to_yaml
      end
  end

  def self.write_site_config(manifest, opts)
    if File.exist?(CONFIG_FILE)
        puts '** Updating site config' unless opts[:quiet]
        update_site_config(manifest, CONFIG_FILE, opts)
    end
  end

  def self.write_volume_pages(manifest, opts={})
    # generate a volume page document for every canvasin the manifest
    puts "** Writing volume pages" unless opts[:quiet]
    FileUtils.rm_rf(VOLUME_PAGE_DIR)
    Dir.mkdir(VOLUME_PAGE_DIR) unless File.directory?(VOLUME_PAGE_DIR)
    unless manifest.sequences.empty?
      manifest.sequences.first.canvases.each_with_index do |canvas,i|
        output_page(canvas, i, opts)
      end
    end
  end

  def self.stem_from_full(full_uri)
    full_uri.sub('full/full/0/default.jpg','')
  end

  def self.info_from_full(full_uri)
    "#{stem_from_full(full_uri)}info.json"
  end

  def self.thumbnail_from_full(full_uri)
    "#{stem_from_full(full_uri)}full/200,/0/default.jpg"
  end

  # Example from https://github.com/sarepal/adnotationes-et-meditationes-in-euangelia-test/blob/gh-pages/_volume_pages/0004.html
  # ---
  # sort_order: 4
  # tei_id: rdx_b73fx.p.idp3591328
  # annotation_count: 0
  # images:
  #   small-thumbnail: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/mini-thumbnail/
  #   json: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/info/
  #   full: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/fs/
  #   page: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/single-page/
  #   thumbnail: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/thumbnail/
  # title: Page 4
  # number: 4
  # ---



  # Generate page metadata from a TEI Page to be used
  # in the jekyll annotation page front matter
  # @param canvas
  # @param index
  def self.page_frontmatter(canvas, index, opts={})
    # by default, use page number from the tei
    page_number = index

    # retrieve page graphic urls by type for inclusion in front matter
    images = {}  # hash of image urls by rend attribute
#      teipage.images.each { |img| images[img.rend] = img.url }
    # TODO: check all values once they are put into use
    #   small-thumbnail: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/mini-thumbnail/
    #   json: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/info/
    #   full: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/fs/
    #   page: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/single-page/
    #   thumbnail: https://readux.ecds.emory.edu/books/emory:b73fx/pages/emory:gtmmg/thumbnail/
    image = canvas.images.first
    full = image.resource['@id']
    page = full
    thumbnail = image.resource.thumbnail || thumbnail_from_full(full)
    small_thumbnail=thumbnail
    info = info_from_full(full)
    images = {
      'small-thumbnail' => small_thumbnail,
      'json' => info,
      'full' => full,
      'page' => page,
      'thumbnail' => thumbnail
    }

    # construct page front matter
    front_matter = {
        'sort_order'=> page_number,
        'canvas_id' => canvas['@id'],
#          'annotation_count' => teipage.annotation_count,
        'annotation_count' => 0,  # TODO
        'images' => images,
#          'title'=> 'Page %s' % page_number,
        'title'=> canvas.label,
        'number' => page_number
    }

    # TODO consider opts[:page_one] functionality; IIIF has something similar with `startCanvas`
    # cf. https://github.com/ecds/teifacsimile-to-jekyll/blob/master/lib/teifacsimile_to_jekyll.rb#L48-L67

    return front_matter
  end




  # Generate a jekyll collection volume page with appropriate yaml
  # metadata from a canvas
  # @param canvas
  def self.output_page(canvas, index, opts={})
    puts "Page #{index}" unless opts[:quiet]
    # base output filename on page number
    path = File.join(VOLUME_PAGE_DIR, "%04d.html" % index)

    front_matter = page_frontmatter(canvas, index, opts)

    File.open(path, 'w') do |file|
      # write out front matter as yaml
      file.write front_matter.to_yaml
      # ensure separation between yaml and page content
      file.write  "\n---\n\n"
      # page text content as html with annotation highlights # TODO annotation highlights
      json_list = fetch_annotation_list(canvas)
      file.write oa_to_display(canvas, json_list)

    end
  end

  def self.fetch_annotation_list(canvas)
    # TODO figure out how to check SSL correctly in production mode
    # TODO add require statement and bundle for open-uri if it's necessary  
    connection = open(canvas.other_content.first['@id'], {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})
    raw_list = connection.read
    json_list = JSON.parse(raw_list)

    json_list
  end

  def self.oa_to_display(canvas, anno_list_json)
    page_ocr_html = ""
    Annotation.ocr_annotations(anno_list_json, canvas) do |anno|
      style="left:#{anno.left_pct}%;top:#{anno.top_pct}%;width:#{anno.width_pct}%;height:#{anno.height_pct}%;text-align:left;font-size:#{anno.font_size}px"
      page_ocr_html << "<div class=\"ocr-line ocrtext\" style=\"#{style}\" data-vhfontsize=\"2\">\n"
      page_ocr_html << "   <span>#{anno.text}</span>\n"
      page_ocr_html << "</div>\n"
    end
    page_ocr_html
  end    

  # Generate annotation metadata from a WebAnnotation to be used
  # in the jekyll annotation page front matter
  # @param annotation
  def self.annotation_frontmatter(annotation)
    front_matter = {
      'annotation_id' => annotation.anno_id,
      'author' => annotation.user,
#        'tei_target' => teinote.target,
      'annotated_page' => annotation.canvas.canvas_id,
      'page_index' => annotation.canvas.index,
#        'target' => teinote.start_target,
    }

    # TODO handle tags
    # if not teinote.tags.empty?
    #   front_matter['tags'] = teinote.tags
    # end

    # TODO handle related pages
    # if not teinote.related_pages.empty?
    #   front_matter['related_pages'] = teinote.related_page_ids
    # end

    # TODO handle targets
    # if teinote.range_target?
    #   front_matter['end_target'] = teinote.end_target
    # end

    return front_matter
  end



  # Generate a jekyll collection annotation with appropriate yaml
  # metadata from a commenting annotation
  # @param annotation
  def self.output_annotation(annotation, opts)
    puts "Annotation #{annotation.anno_id}" unless opts[:quiet]

    # use id without leading annotation- as filename
    # (otherwise results in redundant file path and name/url)
    path = File.join(ANNOTATION_DIR, "%s.md" % annotation.anno_id)
    # TODO consider changing these to HTML instead of Markdown, since our annotations will be in HTML now

    front_matter = annotation_frontmatter(annotation)

    File.open(path, 'w') do |file|
      # write out front matter as yaml
      file.write front_matter.to_yaml
      file.write  "\n---\n"
      # annotation content
      file.write annotation.text
    end
  end


  def self.output_page_annotations(canvas, i, opts)
    # page text content as html with annotation highlights # TODO annotation highlights
    anno_list_json = fetch_annotation_list(canvas)
    Annotation.comment_annotations(anno_list_json, canvas) do |anno|
      print "Found one!"
      output_annotation(anno)
    end
  end

  def self.write_annotations(manifest, dirname, opts={})
    # generate an annotation document for every commenting annotation in the TEI
    puts "** Writing annotations" unless opts[:quiet]
    FileUtils.rm_rf(ANNOTATION_DIR)
    Dir.mkdir(ANNOTATION_DIR) unless File.directory?(ANNOTATION_DIR)

    unless manifest.sequences.empty?
      manifest.sequences.first.canvases.each_with_index do |canvas,i|
        output_page_annotations(canvas, i, opts)
      end
    end
  end

  def self.validate_manifest(service)
    if service['@type'] == "sc:Collection"
      raise ArgumentError, "#{at_id} contains a collection, not an item"
    end

    service
  end    

  def self.load_manifest(dirname)
    manifest_path = File.join(dirname, 'manifest.json')
    manifest_json = File.read(manifest_path)
    manifest = IIIF::Service.parse(manifest_json)

    manifest
  end

end
