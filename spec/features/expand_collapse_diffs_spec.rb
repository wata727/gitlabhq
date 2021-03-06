require 'spec_helper'

feature 'Expand and collapse diffs', js: true, feature: true do
  include WaitForAjax

  before do
    login_as :admin
    project = create(:project)
    branch = 'expand-collapse-diffs'

    # Ensure that undiffable.md is in .gitattributes
    project.repository.copy_gitattributes(branch)
    visit namespace_project_commit_path(project.namespace, project, project.commit(branch))
    execute_script('window.ajaxUris = []; $(document).ajaxSend(function(event, xhr, settings) { ajaxUris.push(settings.url) });')
  end

  def file_container(filename)
    find("[data-blob-diff-path*='#{filename}']")
  end

  # Use define_method instead of let (which is memoized) so that this just works across a
  # reload.
  #
  files = [
    'small_diff.md', 'large_diff.md', 'large_diff_renamed.md', 'undiffable.md',
    'too_large.md', 'too_large_image.jpg'
  ]

  files.each do |file|
    define_method(file.split('.').first) { file_container(file) }
  end

  context 'visiting a commit with collapsed diffs' do
    it 'shows small diffs immediately' do
      expect(small_diff).to have_selector('.code')
      expect(small_diff).not_to have_selector('.nothing-here-block')
    end

    it 'collapses large diffs by default' do
      expect(large_diff).not_to have_selector('.code')
      expect(large_diff).to have_selector('.nothing-here-block')
    end

    it 'collapses large diffs for renamed files by default' do
      expect(large_diff_renamed).not_to have_selector('.code')
      expect(large_diff_renamed).to have_selector('.nothing-here-block')
      expect(large_diff_renamed).to have_selector('.file-title .deletion')
      expect(large_diff_renamed).to have_selector('.file-title .addition')
    end

    it 'shows non-renderable diffs as such immediately, regardless of their size' do
      expect(undiffable).not_to have_selector('.code')
      expect(undiffable).to have_selector('.nothing-here-block')
      expect(undiffable).to have_content('gitattributes')
    end

    it 'does not allow diffs that are larger than the maximum size to be expanded' do
      expect(too_large).not_to have_selector('.code')
      expect(too_large).to have_selector('.nothing-here-block')
      expect(too_large).to have_content('too large')
    end

    it 'shows image diffs immediately, regardless of their size' do
      expect(too_large_image).not_to have_selector('.nothing-here-block')
      expect(too_large_image).to have_selector('.image')
    end

    context 'expanding a diff for a renamed file' do
      before do
        large_diff_renamed.find('.nothing-here-block').click
        wait_for_ajax
      end

      it 'shows the old content' do
        old_line = large_diff_renamed.find('.line_content.old')

        expect(old_line).to have_content('two copies')
      end

      it 'shows the new content' do
        new_line = large_diff_renamed.find('.line_content.new', match: :prefer_exact)

        expect(new_line).to have_content('three copies')
      end
    end

    context 'expanding a large diff' do
      before do
        click_link('large_diff.md')
        wait_for_ajax
      end

      it 'makes a request to get the content' do
        ajax_uris = evaluate_script('ajaxUris')

        expect(ajax_uris).not_to be_empty
        expect(ajax_uris.first).to include('large_diff.md')
      end

      it 'shows the diff content' do
        expect(large_diff).to have_selector('.code')
        expect(large_diff).not_to have_selector('.nothing-here-block')
      end

      context 'adding a comment to the expanded diff' do
        let(:comment_text) { 'A comment' }

        before do
          large_diff.find('.diff-line-num', match: :prefer_exact).hover
          large_diff.find('.add-diff-note').click
          large_diff.find('.note-textarea').send_keys comment_text
          large_diff.find_button('Comment').click
          wait_for_ajax
        end

        it 'adds the comment' do
          expect(large_diff.find('.notes')).to have_content comment_text
        end

        context 'reloading the page' do
          before { refresh }

          it 'collapses the large diff by default' do
            expect(large_diff).not_to have_selector('.code')
            expect(large_diff).to have_selector('.nothing-here-block')
          end

          context 'expanding the diff' do
            before do
              click_link('large_diff.md')
              wait_for_ajax
            end

            it 'shows the diff content' do
              expect(large_diff).to have_selector('.code')
              expect(large_diff).not_to have_selector('.nothing-here-block')
            end

            it 'shows the diff comment' do
              expect(large_diff.find('.notes')).to have_content comment_text
            end
          end
        end
      end
    end

    context 'collapsing an expanded diff' do
      before { click_link('small_diff.md') }

      it 'hides the diff content' do
        expect(small_diff).not_to have_selector('.code')
        expect(small_diff).to have_selector('.nothing-here-block')
      end

      context 're-expanding the same diff' do
        before { click_link('small_diff.md') }

        it 'shows the diff content' do
          expect(small_diff).to have_selector('.code')
          expect(small_diff).not_to have_selector('.nothing-here-block')
        end

        it 'does not make a new HTTP request' do
          expect(evaluate_script('ajaxUris')).not_to include(a_string_matching('small_diff.md'))
        end
      end
    end
  end

  context 'expanding all diffs' do
    before do
      click_link('Expand all')
      wait_for_ajax
      execute_script('window.ajaxUris = []; $(document).ajaxSend(function(event, xhr, settings) { ajaxUris.push(settings.url) });')
    end

    it 'reloads the page with all diffs expanded' do
      expect(small_diff).to have_selector('.code')
      expect(small_diff).not_to have_selector('.nothing-here-block')

      expect(large_diff).to have_selector('.code')
      expect(large_diff).not_to have_selector('.nothing-here-block')
    end

    context 'collapsing an expanded diff' do
      before { click_link('small_diff.md') }

      it 'hides the diff content' do
        expect(small_diff).not_to have_selector('.code')
        expect(small_diff).to have_selector('.nothing-here-block')
      end

      context 're-expanding the same diff' do
        before { click_link('small_diff.md') }

        it 'shows the diff content' do
          expect(small_diff).to have_selector('.code')
          expect(small_diff).not_to have_selector('.nothing-here-block')
        end

        it 'does not make a new HTTP request' do
          expect(evaluate_script('ajaxUris')).not_to include(a_string_matching('small_diff.md'))
        end
      end
    end
  end
end
