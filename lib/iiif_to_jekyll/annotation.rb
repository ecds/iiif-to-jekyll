# Class representing the data we need from WebAnnotations fetched from Readux
# Attributes like `x_px` are data parsed from individual WebAnnotations
# Helper methods like `left_pct` translate raw data into derivative formats 
# needed for Jekyll
# Static methods like `from_oa` or `ocr_annotations` parse WebAnnotation JSON
# hashes and AnnotationLists into usable collections of Annotation objects.
class Annotation
  attr_accessor :x_px, :y_px, :w_px, :h_px, :motivation, :text, :user, :anno_id, :canvas

  # Constants used for distinguishing OCR annotations from scholarly commentary
  module Motivation
    COMMENTING = "['oa:commenting']"
    PAINTING = "sc:painting"
  end

  # Sample source annotation; for reference only
  EXAMPLE_OCR_SOURCE =
   {"@context"=>"http://iiif.io/api/presentation/2/context.json",
    "@id"=>"f87fef89-8176-4416-a7bb-ec0403016189",
    "@type"=>"oa:Annotation",
    "motivation"=>"sc:painting",
    "annotatedBy"=>{"name"=>"OCR"},
    "resource"=>
     {"@type"=>"cnt:ContentAsText",
      "format"=>"text/html",
      "chars"=>"Robert",
      "language"=>"en"},
    "on"=>
     {"full"=>
       "https://0.0.0.0:3000/iiif/v2/readux:t9pgf/canvas/14639457.24233.emory.edu$2",
      "@type"=>"oa:SpecificResource",
      "within"=>
       {"@id"=>"https://0.0.0.0:3000/iiif/v2/readux:t9pgf/manifest",
        "@type"=>"sc:Manifest"},
      "selector"=>
       {"@type"=>"oa:FragmentSelector", "value"=>"xywh=1082,616,172,40"}}}

  # Sample output for OCR display in current system
  EXAMPLE_OCR_OUT=
    '<div class="ocr-line ocrtext" style="left:11.73%;top:64.23%;width:62.94%;height:2%;text-align:left;font-size:19.96px" data-vhfontsize="2">'+
    '  <span>Ad vnamquamque praterea Euangelicam leétionem fua</span>' +
    '</div>'


  # Factory method creating Annotation objects from hashes created by
  # parsing individual JSON WebAnnotations.
  def self.from_oa(json_hash, canvas)
    anno = Annotation.new

    # simple attributes
    anno.text = json_hash['resource']['chars']
    anno.anno_id = json_hash['@id']
    anno.motivation = json_hash['motivation']
    anno.user = json_hash['annotatedBy']['name']

    # complex/parsed attributes
    selector = json_hash['on']['selector']['value']
    md = selector.match /(\d+),(\d+),(\d+),(\d+)/
    anno.x_px = md[1].to_i
    anno.y_px = md[2].to_i
    anno.w_px = md[3].to_i
    anno.h_px = md[4].to_i
    anno.canvas = canvas

    anno
  end

  def font_size 
    h_px
  end

  # helper for line calculation
  def right_x
    x_px + w_px
  end

  # helper for line calculation
  def bottom_y
    y_px + h_px
  end


  Y_MARGIN_OF_ERROR = 10 # pixels considered probably the same line regardless 
  # of skew, strange OCR, or bizarre printing

  # factory method for creating an arry of Annotation objectss from a raw hash
  # parsed from an AnnotationList 
  def self.all_annotations(annotation_list_json, canvas)
    annotations = []
    annotation_list_json['resources'].each do |anno_json|
      annotations << Annotation.from_oa(anno_json, canvas)
    end

    annotations.sort! do |a,b|
      if (a.y_px - b.y_px).abs < Y_MARGIN_OF_ERROR
        a.x_px <=> b.x_px
      else
        a.y_px <=> b.y_px
      end
    end

    annotations
  end

  # factory method parsing only OCR annotations
  def self.ocr_annotations(annotation_list_json, canvas)
    annotations = all_annotations(annotation_list_json, canvas)
    annotations.reject! { |anno| anno.motivation != Motivation::PAINTING }
    annotations || []
  end

  # factory method parsing only commentary annotations
  def self.comment_annotations(annotation_list_json, canvas)
    annotations = all_annotations(annotation_list_json, canvas)
    annotations.reject! { |anno| anno.motivation != Motivation::COMMENTING }
    annotations || []
  end


end
