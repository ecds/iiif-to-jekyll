require "iiif_to_jekyll/version"
require "iiif_to_jekyll/annotation"
require "iiif_to_jekyll/ocr_line"
require 'iiif/presentation'
require 'date'
require 'open-uri'
require 'openssl'

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
  def self.import(manifesturi, dirname, output_dir, opts={})
    if opts[:local_directory]
      manifest = load_manifest(dirname)
    else
      manifest = open_manifest(manifesturi)
    end

    Dir.chdir(output_dir) do
      write_volume_pages(manifest, opts)

      write_annotations(manifest, opts)

# => Functionality not implemented yet in Readux 2
    output_tags(tags_from_manifest(manifest, opts), **opts)

    # Readux 1 copies the TEI files produced by Readux into the static
    # site export so that scholars can download it (from the static site)
    # for reuse.  Should we do something similar with the IIIF bundle?
    # If so, does that need to be the kind heavy-weight export that 
    # includes images?
    # TODO: log issue in Pivotal

      write_site_config(manifest, opts)
    end
  end

  def self.output_tags(tags, opts={})
    puts "** Generating tags" unless opts[:quiet]
    # create data dir if not already present
    Dir.mkdir(DATA_DIR) unless File.directory?(DATA_DIR)
    tag_data = {}
    # create a jekyll data file with tag data
    # structure tag data for lookup by slug, with a name attribute
    tags.each do |tag|
        tag_data[tag] = {'name' => tag}
    end

    File.open(TAG_FILE, 'w') do |file|
        file.write tag_data.to_yaml
    end

    # Create a tag stub file for each tag
    # create tag dir if not already present
    Dir.mkdir(TAG_DIR) unless File.directory?(TAG_DIR)
    tags.each do |tag|
        puts "Tag #{tag}" unless opts[:quiet]
        @tagfile =
        File.open(File.join(TAG_DIR, "#{tag}.md"), 'w') do |file|
            front_matter = {
                'layout' => 'annotation_by_tag',
                'tag' => tag
            }
            file.write front_matter.to_yaml
            file.write  "\n---\n"
        end
    end
  end

  # Update jekyll site config with values from the IIIF manifest
  # and necessary configurations for setting up jekyll collections
  # of volume pages and annotation content.
  # @param manifest
  # @param configfile [String] path to existing config file to be updated
  def self.update_site_config(manifest, configfile, opts={})
    siteconfig = YAML.load_file(configfile)

    # set site title and subtitle from the tei
    siteconfig['title'] = manifest.label
#      siteconfig['tagline'] = teidoc.title_statement.subtitle

    # placeholder description for author to edit (todo: include annotation author name here?)
    siteconfig['description'] = 'An annotated digital edition created with <a href="http://readux.library.emory.edu/">Readux</a>'

    # add urls to readux volume and pdf

    first_canvas = manifest.sequences.first.canvases.first
    # use first page (which should be the cover) as a default splash
    # image for the home page
    siteconfig['homepage_image'] = first_canvas.images.first.resource['@id']


    # TODO
    # add image dimensions to config so that thumbnail display can be tailored
    # to the current volume page size
    # thumbnail_width, thumbnail_height = FastImage.size(teidoc.pages[0].images_by_type['thumbnail'].url)
    # sm_thumbnail_width, sm_thumbnail_height = FastImage.size(teidoc.pages[0].images_by_type['small-thumbnail'].url)
    page_img_width, page_img_height = first_canvas.height, first_canvas.width
    siteconfig['image_size'] = {
      'page' => {'width' => page_img_width, 'height' => page_img_height},
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
      }]
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

    anno_lists_json = fetch_annotation_lists(canvas, opts)
    anno_count=Annotation.comment_annotations(anno_lists_json, canvas).count

    # construct page front matter
    front_matter = {
      'sort_order'=> page_number,
      'canvas_id' => canvas['@id'],
      'annotation_count' => anno_count,
      'images' => images,
#          'title'=> 'Page %s' % page_number,
      'title'=> canvas.label,
      'number' => page_number + 1
    }

    # TODO consider opts[:page_one] functionality; IIIF has something similar with `startCanvas`
    # cf. https://github.com/ecds/teifacsimile-to-jekyll/blob/master/lib/teifacsimile_to_jekyll.rb#L48-L67
        # if an override start page is set, adjust the labels and set an
        # override url
        if opts[:page_one]
            if page_number < opts[:page_one]
                # pages before the start page will be output as front-#
                permalink = '/pages/front-%s/' % page_number
                front_matter['title'] = 'Front %s' % page_number
                front_matter['short_label'] = 'f.'
                front_matter['number'] = page_number + 1
            else
                # otherwise, offset by requested start page (1-based counting)
                adjusted_number = page_number - opts[:page_one] + 1
                permalink = '/pages/%s/' % adjusted_number
                front_matter['title'] = 'Page %s' % adjusted_number
                # default short label configured as p.
                front_matter['number'] = adjusted_number
            end

            front_matter['permalink'] = permalink
        end

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
      json_lists = fetch_annotation_lists(canvas, opts)
      file.write oa_to_display(canvas, json_lists)

    end
  end

  def self.fetch_annotation_lists(canvas, opts={})
    # TODO figure out how to check SSL correctly in production mode
    json_lists = []
    canvas.other_content.each do |endpoint|
      anno_id = endpoint['@id']
      if opts[:local_directory]
        stem = anno_id.gsub(/\W/,'_')
        filename = "#{stem}.json"
        path = File.join(Dir.pwd, 'iiif_export', filename)
        if File.exist?(path)
          raw_list = File.read(path)
        else
          raw_list = '{"@context": "http://iiif.io/api/presentation/2/context.json", "@id": "", "@type": "sc:AnnotationList", "resources": []}'
        end
      else
        connection = open(anno_id, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})
        raw_list = connection.read
      end
      json_lists << JSON.parse(raw_list)
    end
    json_lists
  end

  def self.x_px_to_pct(x, canvas)
    (100 * x.to_f / canvas.width).floor(2)
  end

  def self.y_px_to_pct(y, canvas)
    (100 * y.to_f / canvas.height).floor(2)
  end


  def self.add_highlight_attributes(annotation, text)
    # somehow open up the span in the text and add attributes similar to these:
    # class="annotator-hl" data-annotation-id="0168523d-0d9a-4241-930c-c5a5c946c77c"
    text.gsub('<span', "<span class='annotator-hl' data-annotation-id='#{annotation.anno_id}' ")
  end


  def self.oa_to_display(canvas, anno_lists_json)
    page_ocr_html = ""
    words = Annotation.ocr_annotations(anno_lists_json, canvas)

    # build a hash of ocr_words targeted by annotations on this page
    annotations = Annotation.comment_annotations(anno_lists_json, canvas)
    targets = {}
    annotations.each do |anno|
      targets[anno.target_start] = anno
    end

    state = :outside_target
    current_anno = nil

    lines = OcrLine.lines_from_words(words)
    lines.each do |line|
      left_pct = x_px_to_pct(line.x_min, canvas)
      top_pct = y_px_to_pct(line.y_min, canvas)
      width_pct = x_px_to_pct(line.width, canvas)
      height_pct = y_px_to_pct(line.height, canvas)
      font_size = line.font_size
      style="left:#{left_pct}%;top:#{top_pct}%;width:#{width_pct}%;height:#{height_pct}%;text-align:left;font-size:#{font_size}px"
      page_ocr_html << "<div class=\"ocr-line ocrtext\" style=\"#{style}\" data-vhfontsize=\"2\">\n"
      page_ocr_html << "\t<span>\n\t\t"
      # consider moving font-size to here
      line.annotations.each do |ocr_anno|
        # look for the beginning of an annotation highlight
        if targets[ocr_anno.anno_id]  # TODO this might need parsing to get the GUID from a URI
          state = :inside_target
          current_anno = targets[ocr_anno.anno_id] # TODO see comment above
        end
        
        # look for the end of an annotation highlight
        if state == :inside_target
          if ocr_anno.anno_id == current_anno.target_end #test whether annos are inclusive or not.
            state = :outside_target
            current_anno = nil
          end
        end

        if state == :inside_target
          # apply highlight attributes and link this span to the annotation
          page_ocr_html << "#{add_highlight_attributes(current_anno, ocr_anno.text)} "
        else
          page_ocr_html << "#{ocr_anno.text} "
        end

      end
      page_ocr_html << "\t</span>\n"
      page_ocr_html << "</div>\n"
    end
    annotation_id = "ab00ab28-8cfe-4d03-956d-fa657c5fe7be"
    annotations = Annotation.image_comments(anno_lists_json, canvas)
    annotations.each do |anno|
      left_pct = x_px_to_pct(anno.x_px, canvas)
      top_pct = y_px_to_pct(anno.y_px, canvas)
      width_pct = x_px_to_pct(anno.w_px, canvas)
      height_pct = y_px_to_pct(anno.h_px, canvas)
      annotation_id = anno.anno_id
      style="left:#{left_pct}%;top:#{top_pct}%;width:#{width_pct}%;height:#{height_pct}%;text-align:left;"

      page_ocr_html << "<span class=\"annotator-hl image-annotation-highlight\" data-annotation-id=\"#{annotation_id}\" style=\"#{style}\">
<a class=\"to-annotation\" href=\"##{annotation_id}\" name=\"hl-#{annotation_id}\" id=\"hl-#{annotation_id}\"></a>
</span>"  
      end
    page_ocr_html
  end    

  # Generate annotation metadata from a WebAnnotation to be used
  # in the jekyll annotation page front matter
  # @param annotation
  def self.annotation_frontmatter(annotation, i)
    front_matter = {
      'annotation_id' => annotation.anno_id,
      'author' => annotation.user,
      'tei_target' => annotation.target_start,
      'annotated_page' => annotation.canvas["@id"],
      'page_index' => i - 1,
      'target' => annotation.target_start,
    }

    #TODO handle tags
    if not annotation.tags.empty?
      front_matter['tags'] = annotation.tags
    end

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
  def self.output_annotation(annotation, i, opts)
    puts "Annotation #{annotation.anno_id}" unless opts[:quiet]

    # use id without leading annotation- as filename
    # (otherwise results in redundant file path and name/url)
    path = File.join(ANNOTATION_DIR, "%s.md" % annotation.anno_id)
    # TODO consider changing these to HTML instead of Markdown, since our annotations will be in HTML now

    front_matter = annotation_frontmatter(annotation, i)

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
    anno_lists_json = fetch_annotation_lists(canvas, opts)
    Annotation.comment_annotations(anno_lists_json, canvas).each do |anno|
      output_annotation(anno, i, opts)
    end
  end

  def self.write_annotations(manifest, opts={})
    # generate an annotation document for every commenting annotation
    puts "** Writing annotations" unless opts[:quiet]
    FileUtils.rm_rf(ANNOTATION_DIR)
    Dir.mkdir(ANNOTATION_DIR) unless File.directory?(ANNOTATION_DIR)

    unless manifest.sequences.empty?
      manifest.sequences.first.canvases.each_with_index do |canvas,i|
        output_page_annotations(canvas, i+1, opts)
      end
    end
  end

  def self.validate_manifest(service)
    if service['@type'] == "sc:Collection"
      raise ArgumentError, "#{at_id} contains a collection, not an item"
    end

    service
  end    

  def self.open_manifest(manifest)
    connection = open(manifest, {ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE})
    raw_manifest = connection.read
    json_manifest = JSON.parse(raw_manifest)
    iiif_manifest = IIIF::Service.parse(json_manifest)

    iiif_manifest
  end

  def self.load_manifest(dirname)
    manifest_path = File.join(dirname, 'manifest.json')
    manifest_json = File.read(manifest_path)
    manifest = IIIF::Service.parse(manifest_json)

    manifest
  end

  def self.tags_from_manifest(manifest, opts)
    tags = []
    unless manifest.sequences.empty?
      manifest.sequences.first.canvases.each_with_index do |canvas,i|
        tags += tags_for_canvas(canvas, opts)
      end
    end
    tags.delete_if{|tag| tag == []}
    tags.uniq! || []
  end

  def self.tags_for_canvas(canvas, opts)
    tags = []
    anno_lists_json = fetch_annotation_lists(canvas, opts)
    Annotation.comment_annotations(anno_lists_json, canvas).each do |anno|
      tags += anno.tags
    end
    tags
  end


end
