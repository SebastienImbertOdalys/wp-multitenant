import { __ } from '@wordpress/i18n';
import {
	useBlockProps,
	RichText,
	InspectorControls,
} from '@wordpress/block-editor';

import {
	PanelBody,
	TextControl,
} from '@wordpress/components';

import './editor.scss';

export default function Edit({ attributes, setAttributes }) {
	const {
		content,
		startDate,
		endDate,
	} = attributes;

	return (
		<>
			<InspectorControls>
				<PanelBody
					title={__('Dates', 'mon-bloc')}
					initialOpen={true}
				>
					<p
						style={{
							fontSize: '12px',
							color: '#757575',
							marginBottom: '16px',
						}}
					>
						{__(
							"Ces deux champs permettent de contrôler la période d'affichage de ce contenu.",
							'mon-bloc'
						)}
					</p>
					<TextControl
						label={__('Date de début', 'mon-bloc')}
						type="date"
						value={startDate}
						onChange={(startDate) =>
							setAttributes({ startDate })
						}
					/>

					<TextControl
						label={__('Date de fin', 'mon-bloc')}
						type="date"
						value={endDate}
						onChange={(endDate) =>
							setAttributes({ endDate })
						}
					/>
				</PanelBody>
			</InspectorControls>

			<RichText
				{...useBlockProps()}
				tagName="p"
				value={content}
				onChange={(content) => setAttributes({ content })}
				placeholder={__('Écris quelque chose...', 'mon-bloc')}
			/>
		</>
	);
}