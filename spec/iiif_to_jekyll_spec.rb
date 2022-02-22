# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
require 'tmpdir'

RSpec.describe IiifToJekyll do
  before(:each) do
    @test_export = File.join(Dir.getwd, 'spec', 'test_data', 'all_anno_types')
    @output_dir = Dir.mktmpdir
    FileUtils.cp_r(File.join(@test_export, 'iiif_export'), @output_dir)
  end

  after(:each) do
    # FileUtils.rm_rf(@output_dir)
  end

  it 'has a version number' do
    expect(IiifToJekyll::VERSION).not_to be nil
  end

  it 'creates all the files' do
    options = { local_directory: true, page_one: 2 }
    IiifToJekyll.import('nope', File.join(@output_dir, 'iiif_export'), @output_dir, **options)
    puts @output_dir
    expect(File).to exist(File.join(@output_dir, '_annotations'))
    expected_annotation_files = [
      'aa0e50a0-48ea-4cd9-8926-8946bda0957b.md',
      'b9210405-415d-4152-bb20-c452a64cec7b.md',
      '30e4595c-9018-4ba4-88b3-afc4266010f6.md',
      '7ebd013f-b605-4151-98c9-79bd352f4433.md',
      '546afa77-4e7f-4e90-85ba-71609d61c28d.md',
      'bcf43df5-39d9-4479-a365-59cd209c5af3.md',
      '003794dd-1d08-4f34-a943-0ff6c35ad845.md'
    ]
    expected_annotation_files.each do |f|
      expect(File).to exist(File.join(@output_dir, '_annotations', f))
    end
    expect(File).to exist(File.join(@output_dir, '_data'))
    expect(File).to exist(File.join(@output_dir, '_data', 'tags.yml'))
    expect(File).to exist(File.join(@output_dir, 'tags'))
    expect(File).to exist(File.join(@output_dir, '_volume_pages'))
    expect(File).to exist(File.join(@output_dir, '_volume_pages', '0000.html'))
    expect(File).to exist(File.join(@output_dir, '_volume_pages', '0001.html'))
    expect(File).to exist(File.join(@output_dir, '_volume_pages', '0002.html'))
    expect(File).to exist(File.join(@output_dir, 'overlays', 'ocr', '2.json'))
    expect(File).to exist(File.join(@output_dir, 'overlays', 'annotations', '2.json'))
    expect(File).to exist(File.join(@output_dir, 'tags', 'tag1.md'))
    tag_data = File.read(File.join(@output_dir, '_data', 'tags.yml'))
    expect(tag_data).to include('tag1')
  end

  it 'makes some ocr' do
    manifest = IiifToJekyll.load_manifest(
      File.join(
        Dir.getwd, 'spec', 'test_data', 'all_anno_types', 'iiif_export'
      )
    )
    canvas = manifest.sequences.first.canvases.last
    annotations = nil
    Dir.chdir(File.join(@test_export)) do
      annotations = IiifToJekyll.fetch_annotation_lists(canvas, { local_directory: true })
    end
    # poop = IiifToJekyll.oa_to_display(canvas, annotations)
    # words = Annotation.ocr_annotations(annotations, canvas)
    # puts words.map { |w| "\t#{w.text}\n" }.join('')
  end
end
# rubocop:enable Metrics/BlockLength

# require'./lib/iiif_to_jekyll'
# test_export = File.join(Dir.getwd, 'spec', 'test_data', 'with_css')
# manifest = IiifToJekyll.load_manifest(File.join(Dir.getwd, 'spec', 'test_data', 'with_css', 'iiif_export'))
# canvas = manifest.sequences.first.canvases.last
# annotations = nil
# Dir.chdir(File.join(test_export)) do
#   annotations = IiifToJekyll.fetch_annotation_lists(canvas, { local_directory: true })
# end
# poop = IiifToJekyll.oa_to_display(canvas, annotations)

# require'./lib/iiif_to_jekyll'
# test_export = File.join(Dir.getwd, 'spec', 'test_data', 'without_css')
# manifest = IiifToJekyll.load_manifest(File.join(Dir.getwd, 'spec', 'test_data', 'without_css', 'iiif_export'))
# canvas = manifest.sequences.first.canvases.last
# annotations = nil
# Dir.chdir(File.join(test_export)) do
#   annotations = IiifToJekyll.fetch_annotation_lists(canvas, { local_directory: true })
# end
# poop = IiifToJekyll.oa_to_display(canvas, annotations)
